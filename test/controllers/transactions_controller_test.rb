require "test_helper"

class TransactionsControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  setup do
    @user = users(:one)
    sign_in @user
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

  test "destroy removes paid transfer pair and reverses both balances" do
    @source_account.update!(balance: 900.00)
    source_transaction, destination_transaction = create_paid_transfer_pair

    assert_difference("Transaction.count", -2) do
      delete :destroy, params: { id: source_transaction.id }
    end

    assert_redirected_to transactions_path
    assert_equal "Movimentação removida.", flash[:notice]
    assert_not Transaction.exists?(source_transaction.id)
    assert_not Transaction.exists?(destination_transaction.id)
    assert_equal 1000.00.to_d, @source_account.reload.balance
    assert_equal 500.00.to_d, @destination_account.reload.balance
  end

  test "destroy clears extra legacy references before removing transfer pair" do
    source_transaction, destination_transaction = create_paid_transfer_pair
    legacy_reference = Transaction.create!(
      user: @user,
      bank_account: @source_account,
      title: "Referência legado",
      transaction_type: "expense",
      payment_method: "transfer",
      amount: 10.00,
      due_date: Date.current,
      paid: false,
      related_transfer: source_transaction
    )

    assert_difference("Transaction.count", -2) do
      delete :destroy, params: { id: source_transaction.id }
    end

    assert_redirected_to transactions_path
    assert_not Transaction.exists?(source_transaction.id)
    assert_not Transaction.exists?(destination_transaction.id)
    assert_nil legacy_reference.reload.related_transfer_id
  end

  test "create with same idempotency key does not duplicate transaction or balance update" do
    @source_account.update!(balance: 1000.00)
    idempotency_key = SecureRandom.uuid
    params = {
      transaction: {
        bank_account_id: @source_account.id,
        title: "Mercado",
        transaction_type: "expense",
        payment_method: "debit_card",
        amount: 125.00,
        due_date: Date.current,
        paid: "1",
        idempotency_key: idempotency_key
      }
    }

    assert_difference("Transaction.count", 1) do
      post :create, params: params
    end

    assert_redirected_to transactions_path
    assert_equal 875.00.to_d, @source_account.reload.balance

    assert_no_difference("Transaction.count") do
      post :create, params: params
    end

    assert_redirected_to transactions_path
    assert_equal "Movimentação já processada.", flash[:notice]
    assert_equal 875.00.to_d, @source_account.reload.balance
  end

  test "create transfer with same idempotency key does not duplicate pair or balance updates" do
    @source_account.update!(balance: 1000.00)
    @destination_account.update!(balance: 500.00)
    idempotency_key = SecureRandom.uuid
    params = {
      transaction: {
        bank_account_id: @source_account.id,
        destination_bank_account_id: @destination_account.id,
        title: "Reserva",
        transaction_type: "transfer",
        payment_method: "transfer",
        amount: 200.00,
        due_date: Date.current,
        paid: "1",
        idempotency_key: idempotency_key
      }
    }

    assert_difference("Transaction.count", 2) do
      post :create, params: params
    end

    assert_redirected_to transactions_path
    assert_equal 800.00.to_d, @source_account.reload.balance
    assert_equal 700.00.to_d, @destination_account.reload.balance

    assert_no_difference("Transaction.count") do
      post :create, params: params
    end

    assert_redirected_to transactions_path
    assert_equal "Movimentação já processada.", flash[:notice]
    assert_equal 800.00.to_d, @source_account.reload.balance
    assert_equal 700.00.to_d, @destination_account.reload.balance
  end

  test "mark paid is idempotent and updates balance once" do
    @source_account.update!(balance: 1000.00)
    transaction = Transaction.create!(
      user: @user,
      bank_account: @source_account,
      title: "Conta de luz",
      transaction_type: "expense",
      payment_method: "boleto",
      amount: 80.00,
      due_date: Date.current,
      paid: false
    )

    patch :mark_paid, params: { id: transaction.id }
    assert_redirected_to transactions_path
    assert_equal 920.00.to_d, @source_account.reload.balance

    patch :mark_paid, params: { id: transaction.id }
    assert_redirected_to transactions_path
    assert_equal "Movimentação já estava paga.", flash[:notice]
    assert_equal 920.00.to_d, @source_account.reload.balance
  end

  test "update edits transaction without idempotency key" do
    @source_account.update!(balance: 1000.00)
    transaction = Transaction.create!(
      user: @user,
      bank_account: @source_account,
      title: "Financiamento",
      transaction_type: "expense",
      payment_method: "ted",
      amount: 1500.00,
      due_date: Date.current,
      paid: true
    )

    patch :update, params: {
      id: transaction.id,
      transaction: {
        bank_account_id: @source_account.id,
        title: "Financiamento atualizado",
        transaction_type: "expense",
        payment_method: "ted",
        amount: 1551.93,
        due_date: Date.current,
        paid: "1",
        notes: ""
      }
    }

    assert_redirected_to transactions_path
    assert_equal "Movimentação atualizada!", flash[:notice]
    assert_equal "Financiamento atualizado", transaction.reload.title
    assert_nil transaction.idempotency_key
  end

  test "creates investment transaction and decrements bank account balance when paid" do
    initial_balance = @source_account.balance

    assert_difference("Transaction.count", 1) do
      post :create, params: {
        transaction: {
          title: "Aporte Fundo XP",
          transaction_type: "investment",
          bank_account_id: @source_account.id,
          amount: 250.00,
          due_date: Date.current,
          paid: true
        }
      }
    end

    assert_redirected_to transactions_path
    created_tx = Transaction.last
    assert_equal "investment", created_tx.transaction_type
    assert created_tx.investment?
    assert_equal(initial_balance - 250.00.to_d, @source_account.reload.balance)
  end

  test "index filters by Investimento type successfully" do
    Transaction.create!(
      user: @user,
      bank_account: @source_account,
      title: "Tesouro Selic",
      transaction_type: "investment",
      amount: 500.00,
      due_date: Date.current,
      paid: true
    )

    get :index, params: { type: "Investimento" }
    assert_response :success
    assert_includes assigns(:transactions).map(&:transaction_type), "investment"
  end

  test "index calculates projected balance subtracting pending expenses and unpaid invoices from current balance" do
    @source_account.update!(balance: 1000.00)
    @destination_account.update!(balance: 500.00)

    Transaction.create!(
      user: @user,
      bank_account: @source_account,
      title: "Aluguel Pendente",
      transaction_type: "expense",
      amount: 400.00,
      due_date: Date.current,
      paid: false
    )

    get :index
    assert_response :success
    assert_equal 1500.00.to_d, assigns(:current_balance)
    assert_equal 400.00.to_d, assigns(:expense_unpaid)
    assert_equal 1100.00.to_d, assigns(:projected_balance)
  end

  private

  def create_paid_transfer_pair
    source_transaction = Transaction.create!(
      user: @user,
      bank_account: @source_account,
      destination_bank_account: @destination_account,
      title: "Transferência teste",
      transaction_type: "expense",
      payment_method: "transfer",
      amount: 100.00,
      due_date: Date.current,
      paid: true,
      paid_at: Date.current
    )

    destination_transaction = Transaction.create!(
      user: @user,
      bank_account: @destination_account,
      destination_bank_account: @source_account,
      title: "Transferência teste",
      transaction_type: "income",
      payment_method: "transfer",
      amount: 100.00,
      due_date: Date.current,
      paid: true,
      paid_at: Date.current,
      related_transfer: source_transaction
    )

    source_transaction.update!(related_transfer: destination_transaction)

    [source_transaction, destination_transaction]
  end
end
