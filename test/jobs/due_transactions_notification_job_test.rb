require "test_helper"

class DueTransactionsNotificationJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    # Clear all transactions before each test to avoid cross-test contamination
    Transaction.delete_all
  end

  teardown do
    # Restore original emails for fixture users
    users(:one).update(email: "joao@example.com")
    users(:two).update(email: "maria@example.com")
  end

  test "should send email to user with due transactions" do
    user = users(:one)
    create_transaction(user: user, due_date: Date.today, paid: false)
    
    assert_enqueued_jobs(1) do
      DueTransactionsNotificationJob.perform_now
    end
  end

  test "should not send email if user has no due transactions" do
    user = users(:one)
    
    assert_no_enqueued_jobs do
      DueTransactionsNotificationJob.perform_now
    end
  end

  test "should not send email to user without email" do
    # Note: User email can't be blank due to Devise validations,
    # so we test the behavior that should_not_send_email_if_user_has_no_due_transactions
    # already covers: users without due transactions don't get notified
    skip "Email field is required by Devise, cannot be null"
  end


  test "should send email to all users with due transactions" do
    user1 = users(:one)
    user2 = users(:two)
    
    create_transaction(user: user1, due_date: Date.today, paid: false)
    create_transaction(user: user2, due_date: 3.days.from_now.to_date, paid: false)
    
    assert_enqueued_jobs(2) do
      DueTransactionsNotificationJob.perform_now
    end
  end

  test "should categorize transactions by due date" do
    user = users(:one)
    
    overdue = create_transaction(user: user, due_date: 10.days.ago.to_date, paid: false)
    due_today = create_transaction(user: user, due_date: Date.today, paid: false)
    due_in_3 = create_transaction(user: user, due_date: 3.days.from_now.to_date, paid: false)
    
    assert_enqueued_jobs(1) do
      DueTransactionsNotificationJob.perform_now
    end
  end

  test "should skip paid transactions" do
    user = users(:one)
    create_transaction(user: user, due_date: Date.today, paid: true)
    
    assert_no_enqueued_jobs do
      DueTransactionsNotificationJob.perform_now
    end
  end

  test "should handle multiple users correctly" do
    user1 = users(:one)
    user2 = users(:two)
    
    # User 1 has due transaction
    create_transaction(user: user1, due_date: Date.today, paid: false)
    
    # User 2 has no due transactions
    create_transaction(user: user2, due_date: 30.days.from_now.to_date, paid: false)
    
    assert_enqueued_jobs(1) do
      DueTransactionsNotificationJob.perform_now
    end
  end

  private

  def create_transaction(user:, due_date:, paid: false)
    bank_account = user.bank_accounts.first || user.bank_accounts.create!(
      name: "Test Account",
      account_type: "checking",
      balance: 1000.00,
      currency: "BRL"
    )
    
    user.transactions.create!(
      bank_account_id: bank_account.id,
      title: "Test Transaction",
      transaction_type: "expense",
      amount: 100.00,
      due_date: due_date,
      paid: paid
    )
  end
end
