class CreditCardPurchase < ApplicationRecord
  belongs_to :credit_card
  belongs_to :category, optional: true

  has_many :credit_card_expenses, dependent: :destroy

  validates :title, presence: true
  validates :total_amount, numericality: { other_than: 0 }
  validates :installments, numericality: { greater_than: 0 }
  validates :purchased_at, presence: true

  after_create :auto_categorize_if_needed
  after_create :generate_expenses

  def installment_amount
    (total_amount / installments).round(2)
  end

  private

  def auto_categorize_if_needed
    return if category_id.present?

    user = credit_card.user
    service = AutoCategorizationService.new(title, user)
    found_category = service.call
    if found_category
      update_columns(category_id: found_category.id, auto_categorized: true)
    end
  end

  def generate_expenses
    CreditCardExpenseGeneratorService.new(self).call
  end
end
