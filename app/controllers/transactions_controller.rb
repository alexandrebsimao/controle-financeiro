class TransactionsController < ApplicationController
  require "csv"

  before_action :set_transaction, only: [:show, :edit, :update, :destroy, :mark_paid]

  def index
    # Default to current month/year
    @year = params[:year].present? ? params[:year].to_i : Date.today.year
    @month = params[:month].present? ? params[:month].to_i : Date.today.month

    @month_start = Date.new(@year, @month, 1)
    @month_end = @month_start.end_of_month

    # Calculate previous month period
    @previous_month_start = (@month_start - 1.day).beginning_of_month
    @previous_month_end = (@month_start - 1.day).end_of_month

    # Get user's bank accounts
    @bank_accounts = current_user.bank_accounts.active

    # Get all transactions to calculate balances
    all_transactions = current_user.transactions.includes(:bank_account, :category, :recurrence)

    # Calculate previous month balance (REAL balance, without filters)
    @previous_month_balance = 0
    all_transactions.for_period(Date.new(2000, 1, 1), @previous_month_end).paid.each do |t|
      @previous_month_balance += t.income? ? t.amount : -t.amount
    end

    # Apply filters for display
    @transactions = TransactionsIndexQuery.new(
      scope: all_transactions,
      params: params,
      month_start: @month_start,
      month_end: @month_end
    ).call

    @income_total = @transactions.ignore_transfers.income.sum(:amount)
    @expense_total = @transactions.ignore_transfers.expense.sum(:amount)
    @investment_total = @transactions.ignore_transfers.investment.sum(:amount)
    # Exclude credit card bill payments from regular transaction totals to avoid double counting
    transactions_excluding_cc_bills = @transactions.where("transactions.payment_method != ?", "credit_card_bill")

    @income_paid = @transactions.ignore_transfers.income.paid.sum(:amount)
    @expense_paid = transactions_excluding_cc_bills.ignore_transfers.expense.paid.sum(:amount)
    @investment_paid = @transactions.ignore_transfers.investment.paid.sum(:amount)
    @income_unpaid = @transactions.ignore_transfers.income.unpaid.sum(:amount)
    @expense_unpaid = @transactions.ignore_transfers.expense.unpaid.sum(:amount)
    @investment_unpaid = @transactions.ignore_transfers.investment.unpaid.sum(:amount)

    @month_balance = @income_paid - @transactions.ignore_transfers.expense.paid.sum(:amount)

    @current_balance = @bank_accounts.sum(:balance)

    # Get credit card invoices for the selected month
    # Only load invoices if type filter is NOT "Entrada" or "Investimento" (since invoices are always "Saída")
    # Include both paid and unpaid invoices in totals, but only show unpaid in the display
    all_month_invoices = if params[:type].present? && %w[Entrada Investimento].include?(params[:type])
                           current_user.active_credit_card_invoices.none
                         else
                           current_user.active_credit_card_invoices
                             .includes(:credit_card)
                             .where("reference_year = ? AND reference_month = ?", @year, @month)
                         end

    @expense_total += all_month_invoices.where(paid: false).sum(:total_amount)
    @expense_paid += all_month_invoices.where(paid: true).sum(:total_amount)
    @expense_unpaid += all_month_invoices.where(paid: false).sum(:total_amount)

    @projected_balance = @current_balance - @expense_unpaid

    # Only show unpaid invoices in the display
    @invoices = all_month_invoices.where(paid: false).order(due_date: :desc)

    # Filter invoices by paid status (same logic as transactions)
    unless @invoices.empty?
      if params[:paid].present?
        case params[:paid]
        when "Pendente"
          @invoices = @invoices.where(paid: false).where("due_date >= ?", Date.today)
        when "Atrasado"
          @invoices = @invoices.where(paid: false).where("due_date < ?", Date.today)
        end
      end
    end

    respond_to do |format|
      format.html do
        @transactions = @transactions.page(params[:page]).per(999)
      end

      format.csv do
        send_data transactions_csv(@transactions),
                  filename: "movimentacoes-#{@year}-#{format('%02d', @month)}-#{Date.current}.csv",
                  type: "text/csv; charset=utf-8"
      end
    end
  end

  def show; end

  def new
    @transaction = current_user.transactions.build(due_date: Date.today, idempotency_key: SecureRandom.uuid)
  end

  def create
    if idempotent_transaction
      return redirect_to transactions_path, notice: "Movimentação já processada."
    end

    if create_transaction_params[:transaction_type] == "transfer"
      create_transfer
    else
      create_regular_transaction
    end
  rescue ActiveRecord::RecordNotUnique
    if idempotent_transaction
      redirect_to transactions_path, notice: "Movimentação já processada."
    else
      raise
    end
  end

  def edit; end

  def update
    old_amount = @transaction.amount
    old_paid = @transaction.paid?
    old_type = @transaction.transaction_type

    if @transaction.update(update_transaction_params)
      update_bank_account_balance_on_edit(@transaction, old_amount, old_paid, old_type)
      redirect_to transactions_path, notice: "Movimentação atualizada!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    destroy_transaction_with_related_transfer
    redirect_to transactions_path, notice: "Movimentação removida."
  end

  def mark_paid
    @transaction.with_lock do
      if @transaction.paid?
        return redirect_back fallback_location: transactions_path, notice: "Movimentação já estava paga."
      end

      if @transaction.update(paid: true, paid_at: Date.today)
        update_bank_account_balance(@transaction)
        redirect_back fallback_location: transactions_path, notice: "Movimentação marcada como paga!"
      else
        redirect_back fallback_location: transactions_path, alert: "Erro ao marcar como paga."
      end
    end
  end

  def bulk_mark_paid
    ids = Array(params[:transaction_ids]).map(&:to_i).uniq
    if ids.empty?
      return redirect_back fallback_location: transactions_path, alert: "Selecione pelo menos uma movimentação."
    end

    paid_count = 0
    Transaction.transaction do
      current_user.transactions.where(id: ids).find_each do |transaction|
        transaction.with_lock do
          next if transaction.paid?

          if transaction.update(paid: true, paid_at: Date.today)
            update_bank_account_balance(transaction)
            paid_count += 1
          end
        end
      end
    end

    if paid_count > 0
      redirect_back fallback_location: transactions_path, notice: "#{paid_count} movimentação(ões) marcada(s) como paga(s)!"
    else
      redirect_back fallback_location: transactions_path, notice: "As movimentações selecionadas já estavam pagas."
    end
  end

  def bulk_destroy
    ids = Array(params[:transaction_ids]).map(&:to_i).uniq
    if ids.empty?
      return redirect_back fallback_location: transactions_path, alert: "Selecione pelo menos uma movimentação."
    end

    destroyed_count = 0
    destroyed_ids = []

    Transaction.transaction do
      current_user.transactions.where(id: ids).find_each do |transaction|
        next if destroyed_ids.include?(transaction.id)

        transactions_to_destroy = related_transfer_transactions_for(transaction)
        tx_ids = transactions_to_destroy.map(&:id)

        Transaction.where(related_transfer_id: tx_ids).update_all(related_transfer_id: nil, updated_at: Time.current)

        transactions_to_destroy.each do |tx|
          next if destroyed_ids.include?(tx.id)

          reverse_bank_account_balance(tx) if tx.paid?
          tx.destroy!
          destroyed_ids << tx.id
        end

        destroyed_count += 1
      end
    end

    redirect_back fallback_location: transactions_path, notice: "#{destroyed_count} movimentação(ões) removida(s) com sucesso!"
  end

  private

  def transactions_csv(transactions)
    CSV.generate(headers: true) do |csv|
      csv << ["Titulo", "Tipo", "Categoria", "Conta", "Metodo", "Valor", "Vencimento", "Pago", "Data de pagamento", "Observacoes"]

      transactions.each do |transaction|
        csv << [
          transaction.title,
          transaction.transaction_type,
          transaction.category&.name,
          transaction.bank_account&.name,
          transaction.payment_method,
          transaction.amount,
          transaction.due_date,
          transaction.paid? ? "Sim" : "Nao",
          transaction.paid_at,
          transaction.notes
        ]
      end
    end
  end

  def create_regular_transaction
    @transaction = current_user.transactions.build(transaction_params)

    Transaction.transaction do
      if @transaction.save
        update_bank_account_balance(@transaction)
        redirect_to transactions_path, notice: "Movimentação criada com sucesso!"
      else
        render :new, status: :unprocessable_entity
      end
    end
  end

  def create_transfer
    # Create two transactions: one for the source account (expense) and one for the destination (income)
    source_transaction = current_user.transactions.build(
      bank_account_id: transaction_params[:bank_account_id],
      destination_bank_account_id: transaction_params[:destination_bank_account_id],
      title: transaction_params[:title],
      notes: transaction_params[:notes],
      transaction_type: "expense",
      payment_method: transaction_params[:payment_method] || "transfer",
      amount: transaction_params[:amount],
      due_date: transaction_params[:due_date],
      paid: transaction_params[:paid],
      paid_at: transaction_params[:paid_at],
      category_id: transaction_params[:category_id],
      idempotency_key: transaction_params[:idempotency_key]
    )

    Transaction.transaction do
      if source_transaction.save
        # Create the corresponding income transaction in the destination account
        destination_transaction = current_user.transactions.build(
          bank_account_id: transaction_params[:destination_bank_account_id],
          destination_bank_account_id: transaction_params[:bank_account_id],
          title: transaction_params[:title],
          notes: transaction_params[:notes],
          transaction_type: "income",
          payment_method: transaction_params[:payment_method] || "transfer",
          amount: transaction_params[:amount],
          due_date: transaction_params[:due_date],
          paid: transaction_params[:paid],
          paid_at: transaction_params[:paid_at],
          category_id: transaction_params[:category_id],
          related_transfer_id: source_transaction.id
        )

        if destination_transaction.save
          source_transaction.update(related_transfer_id: destination_transaction.id)

          # Update both bank account balances
          update_bank_account_balance(source_transaction)
          update_bank_account_balance(destination_transaction)

          redirect_to transactions_path, notice: "Transferência criada com sucesso!"
        else
          raise ActiveRecord::Rollback
        end
      else
        raise ActiveRecord::Rollback
      end
    end

    unless performed?
      @transaction = source_transaction
      render :new, status: :unprocessable_entity
    end
  end

  def set_transaction
    @transaction = current_user.transactions.find(params[:id])
  end

  def transaction_params
    create_transaction_params
  end

  def create_transaction_params
    params.require(:transaction).permit(
      :bank_account_id, :destination_bank_account_id, :category_id, :title, :notes, :transaction_type,
      :payment_method, :amount, :due_date, :paid, :paid_at, :idempotency_key
    )
  end

  def update_transaction_params
    params.require(:transaction).permit(
      :bank_account_id, :destination_bank_account_id, :category_id, :title, :notes, :transaction_type,
      :payment_method, :amount, :due_date, :paid, :paid_at
    )
  end

  def idempotent_transaction
    return if transaction_params[:idempotency_key].blank?

    current_user.transactions.find_by(idempotency_key: transaction_params[:idempotency_key])
  end

  def update_bank_account_balance(transaction)
    return unless transaction.paid?
    if transaction.income?
      transaction.bank_account.increment!(:balance, transaction.amount)
    else
      transaction.bank_account.decrement!(:balance, transaction.amount)
    end
  end

  def reverse_bank_account_balance(transaction)
    if transaction.income?
      transaction.bank_account.decrement!(:balance, transaction.amount)
    else
      transaction.bank_account.increment!(:balance, transaction.amount)
    end
  end

  def update_bank_account_balance_on_edit(transaction, old_amount, old_paid, old_type)
    # Reverse old effect
    if old_paid
      if old_type == "income"
        transaction.bank_account.decrement!(:balance, old_amount)
      else
        transaction.bank_account.increment!(:balance, old_amount)
      end
    end
    # Apply new effect
    update_bank_account_balance(transaction)
  end

  def destroy_transaction_with_related_transfer
    Transaction.transaction do
      transactions_to_destroy = related_transfer_transactions
      transaction_ids = transactions_to_destroy.map(&:id)

      Transaction.where(related_transfer_id: transaction_ids).update_all(related_transfer_id: nil, updated_at: Time.current)

      transactions_to_destroy.each do |transaction|
        reverse_bank_account_balance(transaction) if transaction.paid?
        transaction.destroy!
      end
    end
  end

  def related_transfer_transactions(tx = @transaction)
    related_transactions = [tx]
    related_transfer = tx.related_transfer

    if related_transfer&.user_id == current_user.id
      related_transactions << related_transfer
    end

    if related_transfer.blank?
      inverse_related_transfer = current_user.transactions.where(related_transfer_id: tx.id).order(:id).first
      related_transactions << inverse_related_transfer if inverse_related_transfer
    end

    related_transactions.compact.uniq
  end
  alias_method :related_transfer_transactions_for, :related_transfer_transactions
end
