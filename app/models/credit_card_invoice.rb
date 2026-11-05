class CreditCardInvoice < ApplicationRecord
  belongs_to :credit_card
  belongs_to :paid_by_transaction, class_name: 'Transaction', foreign_key: 'transaction_id', optional: true

  has_many :credit_card_expenses, foreign_key: :invoice_id, dependent: :destroy

  validates :reference_month, numericality: { in: 1..12 }
  validates :reference_year, numericality: { greater_than: 2000 }
  validates :closing_date, presence: true
  validates :due_date, presence: true

  scope :upcoming, -> { where(paid: false).where("due_date >= ?", Date.today).order(:due_date) }
  scope :paid, -> { where(paid: true) }
  scope :unpaid, -> { where(paid: false) }
  scope :for_period, ->(start_month, start_year, end_month, end_year) {
    where("(reference_year > :sy OR (reference_year = :sy AND reference_month >= :sm)) AND (reference_year < :ey OR (reference_year = :ey AND reference_month <= :em))",
          sy: start_year, sm: start_month, ey: end_year, em: end_month)
  }

  def reference_label
    Date::MONTHNAMES[reference_month]&.capitalize + " #{reference_year}"
  end

  def overdue?
    !paid? && due_date < Date.today
  end

  def formatted_total
    ActionController::Base.helpers.number_to_currency(total_amount, unit: "R$", separator: ",", delimiter: ".")
  end

  def recalculate_total!
    update!(total_amount: credit_card_expenses.sum(:amount))
  end
end
