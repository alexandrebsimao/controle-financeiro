class BankAccountsController < ApplicationController
  before_action :set_bank_account, only: [:show, :edit, :update, :destroy]

  def index
    @bank_accounts = current_user.bank_accounts.order(:name)
  end

  def show
    @transactions = @bank_account.transactions.recent.includes(:category).page(params[:page]).per(20)
  end

  def new
    @bank_account = current_user.bank_accounts.build
  end

  def create
    @bank_account = current_user.bank_accounts.build(bank_account_params)
    if @bank_account.save
      redirect_to bank_accounts_path, notice: "Conta bancária criada com sucesso!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @bank_account.update(bank_account_params)
      redirect_to bank_accounts_path, notice: "Conta bancária atualizada!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @bank_account.update!(active: false)
    redirect_to bank_accounts_path, notice: "Conta bancária desativada."
  end

  private

  def set_bank_account
    @bank_account = current_user.bank_accounts.find(params[:id])
  end

  def bank_account_params
    params.require(:bank_account).permit(:name, :bank_name, :account_type, :balance, :currency, :color, :active)
  end
end
