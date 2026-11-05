require "test_helper"

class BankAccountsControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  setup do
    @user = users(:one)
    sign_in @user
    @bank_account = bank_accounts(:one)
  end

  # GET /bank_accounts
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:bank_accounts)
    assert_includes assigns(:bank_accounts), @bank_account
  end

  test "index should return bank accounts ordered by name" do
    get :index
    bank_accounts = assigns(:bank_accounts)
    assert_equal bank_accounts, bank_accounts.sort_by(&:name)
  end

  test "index without authentication should redirect to login" do
    sign_out @user
    get :index
    assert_redirected_to new_user_session_path
  end

  # GET /bank_accounts/:id
  test "should get show" do
    get :show, params: { id: @bank_account }
    assert_response :success
    assert_equal @bank_account, assigns(:bank_account)
  end

  test "show should assign transactions" do
    get :show, params: { id: @bank_account }
    assert_not_nil assigns(:transactions)
    assert_kind_of ActiveRecord::Relation, assigns(:transactions)
  end

  test "show should not find account from other user" do
    other_account = bank_accounts(:two)
    assert_raises ActiveRecord::RecordNotFound do
      get :show, params: { id: other_account }
    end
  end

  # GET /bank_accounts/new
  test "should get new" do
    get :new
    assert_response :success
    assert_not_nil assigns(:bank_account)
    assert assigns(:bank_account).new_record?
  end

  test "new should build bank account for current user" do
    get :new
    assert_equal @user, assigns(:bank_account).user
  end

  # POST /bank_accounts
  test "should create bank account with valid params" do
    assert_difference("BankAccount.count") do
      post :create, params: {
        bank_account: {
          name: "Nova Conta",
          bank_name: "Banco XYZ",
          account_type: "checking",
          balance: 1000.00,
          currency: "BRL",
          color: "#FF0000"
        }
      }
    end

    assert_redirected_to bank_accounts_path
    assert_equal "Conta bancária criada com sucesso!", flash[:notice]
    assert_equal @user, BankAccount.last.user
  end

  test "should not create bank account with invalid params" do
    assert_no_difference("BankAccount.count") do
      post :create, params: {
        bank_account: {
          name: "",
          bank_name: nil,
          account_type: "invalid"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "created bank account should belong to current user" do
    post :create, params: {
      bank_account: {
        name: "User Specific",
        bank_name: "Test Bank",
        account_type: "savings",
        balance: 250.00,
        currency: "BRL"
      }
    }

    assert_equal @user, BankAccount.last.user
  end

  # GET /bank_accounts/:id/edit
  test "should get edit" do
    get :edit, params: { id: @bank_account }
    assert_response :success
    assert_equal @bank_account, assigns(:bank_account)
  end

  test "edit should not find account from other user" do
    other_account = bank_accounts(:two)
    assert_raises ActiveRecord::RecordNotFound do
      get :edit, params: { id: other_account }
    end
  end

  # PATCH /bank_accounts/:id
  test "should update bank account with valid params" do
    patch :update, params: {
      id: @bank_account,
      bank_account: {
        name: "Conta Atualizada",
        balance: 2000.00
      }
    }

    assert_redirected_to bank_accounts_path
    assert_equal "Conta bancária atualizada!", flash[:notice]
    @bank_account.reload
    assert_equal "Conta Atualizada", @bank_account.name
    assert_equal 2000.00, @bank_account.balance
  end

  test "should not update bank account with invalid params" do
    original_name = @bank_account.name
    patch :update, params: {
      id: @bank_account,
      bank_account: {
        name: "",
        account_type: "invalid"
      }
    }

    assert_response :unprocessable_entity
    @bank_account.reload
    assert_equal original_name, @bank_account.name
  end

  test "should not update account from other user" do
    other_account = bank_accounts(:two)
    assert_raises ActiveRecord::RecordNotFound do
      patch :update, params: {
        id: other_account,
        bank_account: { name: "Hacked" }
      }
    end
  end

  # DELETE /bank_accounts/:id
  test "should deactivate bank account" do
    @bank_account.update(active: true)
    delete :destroy, params: { id: @bank_account }

    assert_redirected_to bank_accounts_path
    assert_equal "Conta bancária desativada.", flash[:notice]
    @bank_account.reload
    assert_not @bank_account.active?
  end

  test "destroy should not delete account from other user" do
    other_account = bank_accounts(:two)
    assert_raises ActiveRecord::RecordNotFound do
      delete :destroy, params: { id: other_account }
    end
  end

  test "destroy should not allow without authentication" do
    sign_out @user
    delete :destroy, params: { id: @bank_account }
    assert_redirected_to new_user_session_path
  end

  test "destroy should set active to false instead of deleting" do
    assert @bank_account.active?
    delete :destroy, params: { id: @bank_account }
    
    @bank_account.reload
    assert_not @bank_account.active?
    assert BankAccount.find(@bank_account.id).persisted?
  end
end
