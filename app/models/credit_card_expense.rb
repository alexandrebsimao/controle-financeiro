class CreditCardExpense < ApplicationRecord
  belongs_to :credit_card_purchase
  belongs_to :invoice, class_name: "CreditCardInvoice", optional: true

  validates :installment_number, numericality: { greater_than: 0 }
  validates :amount, numericality: { other_than: 0 }
  validates :due_date, presence: true

  after_save :update_invoice_total
  after_destroy :update_invoice_total

  def formatted_amount
    ActionController::Base.helpers.number_to_currency(amount, unit: "R$", separator: ",", delimiter: ".")
  end

  private

  def update_invoice_total
    invoice&.recalculate_total!
    if saved_change_to_invoice_id? && invoice_id_before_last_save
      CreditCardInvoice.find_by(id: invoice_id_before_last_save)&.recalculate_total!
    end
  end
end
