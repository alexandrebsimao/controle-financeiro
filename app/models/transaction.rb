class Transaction < ApplicationRecord
  belongs_to :user
  belongs_to :bank_account
  belongs_to :destination_bank_account, class_name: 'BankAccount', optional: true
  belongs_to :category, optional: true
  belongs_to :recurrence, optional: true
  belongs_to :credit_card, optional: true
  belongs_to :related_transfer, class_name: 'Transaction', optional: true
  has_many :referencing_transfer_transactions, class_name: "Transaction", foreign_key: :related_transfer_id, dependent: :nullify

  TRANSACTION_TYPES = %w[income expense transfer investment].freeze
  PAYMENT_METHODS = {
    "pix" => "Pix",
    "ted" => "TED",
    "boleto" => "Boleto",
    "cash" => "Dinheiro",
    "credit_card_bill" => "Fatura de Cartão",
    "debit_card" => "Cartão de Débito",
    "transfer" => "Transferência",
    "other" => "Outro"
  }
  MONTHS = {
    1 => "Janeiro",
    2 => "Fevereiro",
    3 => "Março",
    4 => "Abril",
    5 => "Maio",
    6 => "Junho",
    7 => "Julho",
    8 => "Agosto", 
    9 => "Setembro",
    10 => "Outubro",
    11 => "Novembro",
    12 => "Dezembro"
  }.freeze

  alias_attribute :description, :title

  validates :title, presence: true
  validates :transaction_type, inclusion: { in: TRANSACTION_TYPES }
  # validates :amount, numericality: { greater_than: 0 }
  validates :due_date, presence: true
  validates :idempotency_key,
            uniqueness: { scope: :user_id },
            allow_blank: true,
            if: :idempotency_key_attribute?

  scope :income, -> { where(transaction_type: "income") }
  scope :expense, -> { where(transaction_type: "expense") }
  scope :investment, -> { where(transaction_type: "investment") }
  scope :paid, -> { where(paid: true) }
  scope :unpaid, -> { where(paid: false) }
  scope :for_period, ->(start_date, end_date) { where(due_date: start_date..end_date) }
  scope :recent, -> { order(due_date: :desc) }
  scope :upcoming, -> { where(paid: false).where("due_date >= ?", Date.today).order(:due_date) }
  scope :overdue, -> { where(paid: false).where("due_date < ?", Date.today) }
  scope :ignore_transfers, -> { where(related_transfer_id: nil) }

  before_save :auto_categorize, if: -> { category_id.nil? && title.present? }
  before_save :set_paid_at, if: -> { paid_changed? && paid? }

  def income?
    transaction_type == "income"
  end

  def expense?
    transaction_type == "expense"
  end

  def transfer?
    transaction_type == "transfer"
  end

  def investment?
    transaction_type == "investment"
  end

  def overdue?
    !paid? && due_date < Date.today
  end

  def formatted_amount
    ActionController::Base.helpers.number_to_currency(amount, unit: "R$", separator: ",", delimiter: ".")
  end

  private

  def idempotency_key_attribute?
    has_attribute?(:idempotency_key)
  end

  def auto_categorize
    service = AutoCategorizationService.new(title, user)
    found_category = service.call
    if found_category
      self.category = found_category
      self.auto_categorized = true
    end
  end

  def set_paid_at
    self.paid_at = Date.today if paid_at.nil?
  end
end
