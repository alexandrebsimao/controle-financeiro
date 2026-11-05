class TransactionsIndexQuery
  TYPE_LABEL_MAP = {
    "Entrada" => "income",
    "Saída" => "expense",
    "Investimento" => "investment"
  }.freeze

  def initialize(scope:, params:, month_start:, month_end:, today: Date.today)
    @scope = scope
    @params = params
    @month_start = month_start
    @month_end = month_end
    @today = today
  end

  def call
    transactions = scope.order(due_date: :desc)
    transactions = apply_type_filter(transactions)
    transactions = apply_bank_account_filter(transactions)
    transactions = apply_category_filter(transactions)
    transactions = apply_paid_filter(transactions)

    transactions.for_period(month_start, month_end)
  end

  private

  attr_reader :scope, :params, :month_start, :month_end, :today

  def apply_type_filter(transactions)
    return transactions unless params[:type].present?

    transaction_type = TYPE_LABEL_MAP.fetch(params[:type], params[:type])
    transactions.where(transaction_type: transaction_type)
  end

  def apply_bank_account_filter(transactions)
    return transactions unless params[:bank_account_id].present?

    transactions.where(bank_account_id: params[:bank_account_id])
  end

  def apply_category_filter(transactions)
    return transactions unless params[:category_id].present?

    transactions.where(category_id: params[:category_id])
  end

  def apply_paid_filter(transactions)
    return transactions unless params[:paid].present?

    case params[:paid]
    when "Pago"
      transactions.where(paid: true)
    when "Pendente"
      transactions.where(paid: false).where("due_date >= ?", today)
    when "Atrasado"
      transactions.where(paid: false).where("due_date < ?", today)
    else
      transactions
    end
  end
end
