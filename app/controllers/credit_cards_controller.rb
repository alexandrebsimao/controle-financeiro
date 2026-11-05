class CreditCardsController < ApplicationController
  before_action :set_credit_card, only: [:show, :edit, :update, :destroy]

  def index
    @credit_cards = current_user.credit_cards.active.order(:name)
  end

  def show
    @invoices = @credit_card.credit_card_invoices.order(reference_year: :desc, reference_month: :desc)
    @purchases = @credit_card.credit_card_purchases.limit(10)
  end

  def new
    @credit_card = current_user.credit_cards.build
    @bank_accounts = current_user.bank_accounts.active
  end

  def create
    @credit_card = current_user.credit_cards.build(credit_card_params)
    if @credit_card.save
      InvoiceCreatorService.new(@credit_card).generate_future_invoices
      redirect_to credit_cards_path, notice: "Cartão de crédito criado com sucesso!"
    else
      @bank_accounts = current_user.bank_accounts.active
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @bank_accounts = current_user.bank_accounts.active
  end

  def update
    if @credit_card.update(credit_card_params)
      redirect_to credit_cards_path, notice: "Cartão de crédito atualizado!"
    else
      @bank_accounts = current_user.bank_accounts.active
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @credit_card.update!(active: false)
    redirect_to credit_cards_path, notice: "Cartão de crédito desativado."
  end

  private

  def set_credit_card
    @credit_card = current_user.credit_cards.find(params[:id])
  end

  def credit_card_params
    params.require(:credit_card).permit(:name, :brand, :bank_account_id, :credit_limit, :closing_day, :due_day, :color, :active)
  end
end
