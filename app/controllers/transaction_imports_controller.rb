# frozen_string_literal: true

class TransactionImportsController < ApplicationController
  before_action :load_form_data, only: [:new, :preview]

  def new
    @selected_provider = current_user.preferred_ai_provider.presence || AiService.default_provider(current_user)
    @mark_paid = true
  end

  def preview
    uploaded_file = params[:statement_file] || params[:statement_pdf] || params[:file]
    bank_account_id = params[:bank_account_id]
    provider = params[:provider].presence || current_user.preferred_ai_provider.presence || AiService.default_provider(current_user)
    mark_paid = params[:mark_paid] == "1"

    if uploaded_file.blank?
      flash.now[:alert] = "Por favor, selecione um arquivo de extrato bancário em formato PDF, OFX ou CSV."
      return render :new, status: :unprocessable_entity
    end

    if bank_account_id.blank?
      flash.now[:alert] = "Selecione uma conta bancária para vincular as movimentações do extrato."
      return render :new, status: :unprocessable_entity
    end

    @bank_account = current_user.bank_accounts.find(bank_account_id)

    # Executa o serviço de análise e extração com a IA
    service = BankStatementImportService.new(
      user: current_user,
      bank_account: @bank_account,
      file_content: uploaded_file,
      file_name: uploaded_file.original_filename,
      provider: provider,
      mark_paid: mark_paid
    )

    result = service.call

    @preview_id = SecureRandom.uuid
    @items = result.items
    @total_items = result.total_items
    @total_income = result.total_income
    @total_expense = result.total_expense
    @net_balance = result.net_balance
    @file_format = result.file_format
    @provider_used = result.provider_used
    @provider_name = result.provider_name
    @provider_badge = result.provider_badge
    @model_used = result.model_used
    @mark_paid = result.mark_paid
    @categories = Category.for_user(current_user).order(:name)

    # Armazena a prévia no cache para o passo de confirmação (expira em 30 minutos)
    store_preview_cache(@preview_id, {
      bank_account_id: @bank_account.id,
      items: @items,
      file_format: @file_format,
      provider_used: @provider_used,
      model_used: @model_used,
      mark_paid: @mark_paid
    })

    flash.now[:notice] = "Extrato #{@file_format} analisado com sucesso pela IA (#{@provider_badge})! Foram identificados #{@total_items} lançamento(s)."
    render :preview
  rescue BankStatementImportService::ImportError => e
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error("Erro no processamento da prévia do extrato: #{e.message}\n#{e.backtrace.first(10).join("\n")}")
    flash.now[:alert] = "Erro inesperado ao analisar o extrato: #{e.message}"
    render :new, status: :unprocessable_entity
  end

  def create
    preview_id = params[:preview_id]
    cached_data = read_preview_cache(preview_id)

    if cached_data.blank?
      redirect_to new_transaction_import_path, alert: "A sessão de importação expirou ou é inválida. Por favor, envie o extrato novamente."
      return
    end

    bank_account_id = params[:bank_account_id].presence || cached_data[:bank_account_id] || cached_data["bank_account_id"]
    bank_account = current_user.bank_accounts.find(bank_account_id)
    selected_row_ids = Array(params[:selected_rows]).map(&:to_s)
    submitted_items = (params[:items].respond_to?(:to_unsafe_h) ? params[:items].to_unsafe_h : params[:items] || {}).with_indifferent_access

    if selected_row_ids.empty?
      @preview_id = preview_id
      @bank_account = bank_account
      @items = cached_data[:items] || cached_data["items"]
      @categories = Category.for_user(current_user).order(:name)
      flash.now[:alert] = "Selecione ao menos uma movimentação para realizar a importação."
      return render :preview, status: :unprocessable_entity
    end

    imported_count = 0
    reference_date = Date.today

    ActiveRecord::Base.transaction do
      (cached_data[:items] || cached_data["items"]).each do |item|
        item = item.with_indifferent_access
        row_id = item[:row_id].to_s
        next unless selected_row_ids.include?(row_id)

        # Permite que edições feitas pelo usuário no formulário de prévia substituam os valores da IA
        row_params = (submitted_items[row_id] || {}).with_indifferent_access
        
        final_title = row_params[:title].presence || item[:title]
        final_amount = (row_params[:amount].presence || item[:amount]).to_s.tr(",", ".").to_f.abs
        final_type = row_params[:transaction_type].presence || item[:transaction_type]
        final_date = Date.parse(row_params[:due_date].presence || item[:due_date].to_s) rescue Date.today
        final_category_id = row_params[:category_id].presence || item[:category_id]
        final_payment_method = row_params[:payment_method].presence || item[:payment_method]
        final_notes = row_params[:notes].presence || item[:notes]
        mark_as_paid = (row_params[:paid] == "1" || item[:paid] == true)

        reference_date = final_date

        transaction = current_user.transactions.build(
          bank_account_id: bank_account.id,
          title: final_title,
          amount: final_amount,
          transaction_type: final_type,
          due_date: final_date,
          paid: mark_as_paid,
          paid_at: (mark_as_paid ? final_date : nil),
          category_id: final_category_id.presence,
          payment_method: final_payment_method.presence || "other",
          notes: final_notes,
          idempotency_key: "import-stmt-#{current_user.id}-#{bank_account.id}-#{final_date}-#{final_amount}-#{SecureRandom.hex(6)}"
        )

        transaction.save!

        # Atualizar saldo da conta bancária se marcado como pago
        if transaction.paid?
          if transaction.income?
            bank_account.increment!(:balance, transaction.amount)
          else
            bank_account.decrement!(:balance, transaction.amount)
          end
        end

        imported_count += 1
      end
    end

    clear_preview_cache(preview_id)

    redirect_to transactions_path(month: reference_date.month, year: reference_date.year),
                notice: "🎉 #{imported_count} movimentação(ões) importada(s) com sucesso na conta #{bank_account.name}!"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to new_transaction_import_path, alert: "Erro de validação ao salvar as movimentações: #{e.record.errors.full_messages.to_sentence}"
  rescue StandardError => e
    Rails.logger.error("Erro ao salvar importação de extrato: #{e.message}\n#{e.backtrace.first(10).join("\n")}")
    redirect_to new_transaction_import_path, alert: "Erro inesperado ao salvar a importação: #{e.message}"
  end

  def cancel
    clear_preview_cache(params[:preview_id]) if params[:preview_id].present?
    redirect_to transactions_path, notice: "Importação de extrato cancelada."
  end

  private

  def load_form_data
    @bank_accounts = current_user.bank_accounts.active.order(:name)
    @providers = AiService.providers(current_user)
  end

  def cache_key_for(preview_id)
    "transaction_statement_preview:user:#{current_user.id}:#{preview_id}"
  end

  def store_preview_cache(preview_id, data)
    Rails.cache.write(cache_key_for(preview_id), data, expires_in: 30.minutes)
  end

  def read_preview_cache(preview_id)
    return nil if preview_id.blank?
    data = Rails.cache.read(cache_key_for(preview_id))
    data&.with_indifferent_access
  end

  def clear_preview_cache(preview_id)
    return if preview_id.blank?
    Rails.cache.delete(cache_key_for(preview_id))
  end
end
