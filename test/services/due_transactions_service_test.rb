require "test_helper"

class DueTransactionsServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "should return empty hash when no due transactions" do
    Transaction.where(user_id: @user.id).delete_all
    
    result = DueTransactionsService.call(@user)
    
    assert result[:overdue].empty?
    assert result[:due_today].empty?
    assert result[:due_in_3_days].empty?
    assert result[:due_in_5_days].empty?
  end

  test "should find overdue transactions" do
    create_transaction(due_date: 5.days.ago, paid: false)
    create_transaction(due_date: 1.day.ago, paid: false)
    create_transaction(due_date: Date.yesterday, paid: false)
    
    result = DueTransactionsService.call(@user)
    
    assert_equal 3, result[:overdue].count
  end

  test "should find today's due transactions" do
    create_transaction(due_date: Date.today, paid: false)
    create_transaction(due_date: Date.today, paid: false)
    
    result = DueTransactionsService.call(@user)
    
    assert_equal 2, result[:due_today].count
  end

  test "should find transactions due in 3 days" do
    create_transaction(due_date: 3.days.from_now.to_date, paid: false)
    
    result = DueTransactionsService.call(@user)
    
    assert_equal 1, result[:due_in_3_days].count
  end

  test "should find transactions due in 5 days" do
    create_transaction(due_date: 5.days.from_now.to_date, paid: false)
    
    result = DueTransactionsService.call(@user)
    
    assert_equal 1, result[:due_in_5_days].count
  end

  test "should not include paid transactions" do
    create_transaction(due_date: Date.today, paid: true)
    create_transaction(due_date: 1.day.ago, paid: true)
    
    result = DueTransactionsService.call(@user)
    
    assert result[:overdue].empty?
    assert result[:due_today].empty?
  end

  test "should only return transactions for the specified user" do
    other_user = users(:two)
    
    create_transaction(user: @user, due_date: Date.today, paid: false)
    create_transaction(user: other_user, due_date: Date.today, paid: false)
    
    result = DueTransactionsService.call(@user)
    
    assert_equal 1, result[:due_today].count
    assert_equal @user.id, result[:due_today].first.user_id
  end

  private

  def create_transaction(attributes = {})
    defaults = {
      user_id: @user.id,
      bank_account_id: @user.bank_accounts.first&.id || create_bank_account.id,
      title: "Test Transaction",
      transaction_type: "expense",
      amount: 100.00,
      paid: false
    }
    
    Transaction.create!(defaults.merge(attributes))
  end

  def create_bank_account
    @user.bank_accounts.create!(
      name: "Test Account",
      account_type: "checking",
      balance: 1000.00
    )
  end
end
