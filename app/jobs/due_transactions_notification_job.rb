class DueTransactionsNotificationJob < ApplicationJob
  queue_as :default

  def perform
    User.find_each do |user|
      next if user.email.blank?

      due_transactions = fetch_user_due_transactions(user)
      
      send_email(user) if has_transactions_to_notify?(due_transactions)
    end
  end

  private

  def fetch_user_due_transactions(user)
    {
      overdue: user.transactions.unpaid.where("due_date < ?", Date.today),
      due_today: user.transactions.unpaid.where(due_date: Date.today),
      due_in_3_days: user.transactions.unpaid.where(due_date: 3.days.from_now.to_date),
      due_in_5_days: user.transactions.unpaid.where(due_date: 5.days.from_now.to_date)
    }
  end

  def has_transactions_to_notify?(due_transactions)
    due_transactions.values.any? { |transactions| transactions.any? }
  end

  def send_email(user)
    TransactionMailer.due_transactions_notification(user).deliver_later
  end
end
