class RecurrenceUpdateService
  attr_reader :recurrence, :params, :update_type, :from_index

  # update_type: 'all' | 'from_index'
  # from_index: índice da ocorrência onde começa a atualizar (ex: 5 = atualiza de índice 5 em diante)
  def initialize(recurrence, params, update_type: 'all', from_index: nil)
    @recurrence = recurrence
    @params = params
    @update_type = update_type
    @from_index = from_index
  end

  def call
    case update_type
    when 'all'
      update_all
    when 'from_index'
      update_from_index
    else
      raise "Invalid update_type: #{update_type}"
    end
  end

  private

  # Atualiza recorrência inteira e todas as futuras transações
  def update_all
    # Identifica se houve mudanças críticas (frequência, intervalo, start_date)
    critical_changes = detect_critical_changes

    if @recurrence.update(params)
      # Se há mudanças críticas: deleta e regenera apenas as futuras
      # Se não há: apenas atualiza os valores das transações existentes
      if critical_changes.any?
        regenerate_future_transactions
      else
        # Atualiza TODAS as transações não pagas com novos valores
        update_future_transactions(from_index: 1)
      end
      
      { success: true, message: 'Recorrência atualizada com sucesso!', type: 'all' }
    else
      { success: false, errors: @recurrence.errors.full_messages }
    end
  end

  # Atualiza recorrência e transações apenas a partir de um índice específico
  def update_from_index
    raise "from_index is required for 'from_index' update type" unless from_index.present?
    raise "from_index must be >= 1" if from_index.to_i < 1

    # Valida se a recorrência pode ser atualizada
    unless @recurrence.active?
      return { success: false, errors: ['Recorrência inativa não pode ser atualizada'] }
    end

    if @recurrence.update(params)
      # Atualiza apenas as transações a partir do índice especificado
      updated_count = update_future_transactions(from_index: from_index.to_i)
      
      {
        success: true,
        message: "Recorrência e #{updated_count} transações atualizadas a partir da ocorrência ##{from_index}",
        type: 'from_index',
        updated_transactions: updated_count
      }
    else
      { success: false, errors: @recurrence.errors.full_messages }
    end
  end

  def detect_critical_changes
    critical_keys = %w[frequency interval start_date total_occurrences end_date]
    params.to_h.slice(*critical_keys)
  end

  # Atualiza transações futuras com novos valores (exceto data/frecuência)
  def update_future_transactions(from_index: 1)
    # Campos que podem ser atualizados nas transações
    updatable_fields = {
      title: params[:title],
      amount: params[:amount],
      category_id: params[:category_id],
      payment_method: params[:payment_method]
    }.compact

    # Encontra transações desta recorrência a partir do índice
    transactions = Transaction.where(recurrence_id: @recurrence.id, paid: false)
                               .where('recurrence_index >= ?', from_index)
                               .order(:recurrence_index)

    updated_count = 0
    transactions.find_each do |transaction|
      if transaction.update(updatable_fields)
        updated_count += 1
      end
    end

    updated_count
  end

  def regenerate_future_transactions
    # Encontra a última transação paga ou a mais recente mantida
    last_transaction = Transaction.where(recurrence_id: @recurrence.id)
                                  .order(recurrence_index: :desc)
                                  .first

    if last_transaction.present?
      # Define occurrences_generated baseado no índice da última transação mantida
      # Assim a próxima geração continua de onde parou
      @recurrence.update(occurrences_generated: last_transaction.recurrence_index)
      
      # Deleta transações a partir do índice seguinte
      Transaction.where(recurrence_id: @recurrence.id)
                 .where('recurrence_index > ?', last_transaction.recurrence_index)
                 .delete_all
    else
      # Se não houver transação, reseta para gerar do início
      @recurrence.update(occurrences_generated: 0)
    end

    # Regenera as próximas transações a partir de onde parou
    RecurrenceGeneratorService.new(@recurrence).call
  end
end
