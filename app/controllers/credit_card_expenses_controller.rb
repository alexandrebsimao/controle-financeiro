class CreditCardExpensesController < ApplicationController
  before_action :set_credit_card
  before_action :set_purchase
  before_action :set_expense, only: [:edit, :update, :destroy]

  def edit
  end

  def update
    if @expense.update(expense_params)
      redirect_to credit_card_purchase_path(@credit_card, @purchase), notice: "Parcela atualizada com sucesso!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @expense.destroy
    redirect_to credit_card_purchase_path(@credit_card, @purchase), notice: "Parcela removida."
  end

  private

  def set_credit_card
    @credit_card = current_user.credit_cards.find(params[:credit_card_id])
  end

  def set_purchase
    @purchase = @credit_card.credit_card_purchases.find(params[:credit_card_purchase_id])
  end

  def set_expense
    @expense = @purchase.credit_card_expenses.find(params[:id])
  end

  def expense_params
    params.require(:credit_card_expense).permit(:amount, :due_date)
  end
end
