require "test_helper"

class TransactionTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @source_account = bank_accounts(:one)
    @destination_account = BankAccount.create!(
      user: @user,
      name: "Conta Destino",
      bank_name: "Banco Teste",
      account_type: "checking",
      balance: 600.00,
      currency: "BRL",
      active: true
    )
  end

  test "nullifies related transfer references when referenced transaction is destroyed" do
    source_transaction = create_transaction(@source_account, "expense")
    referenced_transaction = create_transaction(@destination_account, "income", related_transfer: source_transaction)

    source_transaction.destroy!

    assert_nil referenced_transaction.reload.related_transfer_id
  end

  private

  def create_transaction(bank_account, transaction_type, attributes = {})
    Transaction.create!(
      {
        user: @user,
        bank_account: bank_account,
        title: "Transferência teste",
        transaction_type: transaction_type,
        payment_method: "transfer",
        amount: 100.00,
        due_date: Date.current,
        paid: false
      }.merge(attributes)
    )
  end
end
