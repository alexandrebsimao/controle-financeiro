class RecurrencesController < ApplicationController
  before_action :set_recurrence, only: [:show, :edit, :update, :destroy, :activate, :deactivate]

  def index
    @recurrences = current_user.recurrences.order(start_date: :desc)
  end

  def show
    @transactions = @recurrence.transactions.order(due_date: :desc).limit(10)
  end

  def new
    @recurrence = current_user.recurrences.build(start_date: Date.today)
    @bank_accounts = current_user.bank_accounts.active
    @categories = current_user.categories.for_user(current_user)
  end

  def create
    @recurrence = current_user.recurrences.build(recurrence_params)
    if @recurrence.save
      # Generate initial transactions
      RecurrenceGeneratorService.new(@recurrence).call
      redirect_to @recurrence, notice: "Recorrência criada com sucesso!"
    else
      @bank_accounts = current_user.bank_accounts.active
      @categories = current_user.categories.for_user(current_user)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @bank_accounts = current_user.bank_accounts.active
    @categories = current_user.categories.for_user(current_user)
    @critical_changes = @recurrence.has_critical_changes?
  end

  def update
    # Determina o tipo de atualização
    update_type = params[:recurrence][:update_type] || 'all'
    from_index = params[:recurrence][:from_index]&.to_i

    # Remove parâmetros de controle antes de passar para o serviço
    recurrence_attrs = recurrence_params.except(:update_type, :from_index)

    # Usa o serviço de atualização
    result = RecurrenceUpdateService.new(
      @recurrence,
      recurrence_attrs,
      update_type: update_type,
      from_index: from_index
    ).call

    if result[:success]
      redirect_to @recurrence, notice: result[:message]
    else
      @bank_accounts = current_user.bank_accounts.active
      @categories = current_user.categories.for_user(current_user)
      @error_messages = result[:errors]
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @recurrence.destroy
    redirect_to recurrences_path, notice: "Recorrência removida."
  end

  def activate
    @recurrence.update!(active: true)
    redirect_back fallback_location: @recurrence, notice: "Recorrência ativada!"
  end

  def deactivate
    @recurrence.update!(active: false)
    redirect_back fallback_location: @recurrence, notice: "Recorrência desativada."
  end

  private

  def set_recurrence
    @recurrence = current_user.recurrences.find(params[:id])
  end

  def recurrence_params
    params.require(:recurrence).permit(
      :title, :transaction_type, :amount, :frequency, :interval,
      :bank_account_id, :category_id, :payment_method,
      :start_date, :end_date, :total_occurrences, :active,
      :update_type, :from_index
    )
  end
end
