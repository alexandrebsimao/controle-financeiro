class DueTransactionsService
  def self.call(user)
    new(user).call
  end

  def initialize(user)
    @user = user
  end

  def call
    transactions_by_category = {
      overdue: overdue_transactions,
      due_today: due_today_transactions,
      due_in_3_days: due_in_3_days_transactions,
      due_in_5_days: due_in_5_days_transactions
    }

    transactions_by_category
  end

  private

  def overdue_transactions
    @user.transactions.unpaid.where("due_date < ?", Date.today)
         .order(:due_date)
  end

  def due_today_transactions
    @user.transactions.unpaid.where(due_date: Date.today)
         .order(:due_date)
  end

  def due_in_3_days_transactions
    @user.transactions.unpaid.where(due_date: 3.days.from_now.to_date)
         .order(:due_date)
  end

  def due_in_5_days_transactions
    @user.transactions.unpaid.where(due_date: 5.days.from_now.to_date)
         .order(:due_date)
  end
end
