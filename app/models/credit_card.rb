class CreditCard < ApplicationRecord
  belongs_to :user
  belongs_to :bank_account

  has_many :credit_card_invoices, dependent: :destroy
  has_many :credit_card_purchases, dependent: :destroy
  has_many :transactions

  BRANDS = %w[visa mastercard elo amex hipercard other].freeze

  validates :name, presence: true
  validates :closing_day, numericality: { in: 1..31 }
  validates :due_day, numericality: { in: 1..31 }

  scope :active, -> { where(active: true) }

  def current_invoice
    today = Date.today
    current_month_invoice(today) || next_month_invoice(today)
  end

  def invoice_for(year, month)
    credit_card_invoices.find_by(reference_year: year, reference_month: month)
  end

  def calculate_closing_date_for(purchase_date)
    # If purchased before closing day, falls into current month's invoice
    # If on/after closing day, falls into next month's invoice
    if purchase_date.day < closing_day
      Date.new(purchase_date.year, purchase_date.month, closing_day)
    else
      (purchase_date.next_month).beginning_of_month.change(day: [closing_day, (purchase_date.next_month).end_of_month.day].min)
    end
  end

  def reference_month_for(purchase_date)
    if purchase_date.day < closing_day
      { month: purchase_date.month, year: purchase_date.year }
    else
      next_m = purchase_date.next_month
      { month: next_m.month, year: next_m.year }
    end
  end

  private

  def current_month_invoice(today)
    credit_card_invoices.find_by(reference_year: today.year, reference_month: today.month)
  end

  def next_month_invoice(today)
    next_m = today.next_month
    credit_card_invoices.find_by(reference_year: next_m.year, reference_month: next_m.month)
  end
end
