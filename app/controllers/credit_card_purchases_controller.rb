class CreditCardPurchasesController < ApplicationController
  before_action :set_credit_card
  before_action :set_purchase, only: [:show, :edit, :update, :destroy]

  def index
    @purchases = @credit_card.credit_card_purchases.order(purchased_at: :desc).page(params[:page]).per(20)
  end

  def show
    @expenses = @purchase.credit_card_expenses.includes(:invoice)
  end

  def new
    @purchase = @credit_card.credit_card_purchases.build
    @categories = current_user.categories.for_user(current_user)
  end

  def create
    @purchase = @credit_card.credit_card_purchases.build(purchase_params)
    if @purchase.save
      redirect_to @credit_card, notice: "Compra registrada com sucesso!"
    else
      @categories = current_user.categories.for_user(current_user)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @categories = current_user.categories.for_user(current_user)
  end

  def update
    if @purchase.update(purchase_params)
      redirect_to @credit_card, notice: "Compra atualizada!"
    else
      @categories = current_user.categories.for_user(current_user)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @purchase.destroy
    redirect_to @credit_card, notice: "Compra removida."
  end

  private

  def set_credit_card
    @credit_card = current_user.credit_cards.find(params[:credit_card_id])
  end

  def set_purchase
    @purchase = @credit_card.credit_card_purchases.find(params[:id])
  end

  def purchase_params
    params.require(:credit_card_purchase).permit(:title, :total_amount, :installments, :category_id, :purchased_at, :notes)
  end
end
