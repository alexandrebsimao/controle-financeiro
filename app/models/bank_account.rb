class BankAccount < ApplicationRecord
  belongs_to :user

  has_many :transactions, dependent: :destroy
  has_many :credit_cards, dependent: :destroy
  has_many :recurrences, dependent: :destroy

  ACCOUNT_TYPES = %w[checking savings investment].freeze

  validates :name, presence: true
  validates :account_type, inclusion: { in: ACCOUNT_TYPES }
  validates :balance, numericality: true
  validates :currency, presence: true

  scope :active, -> { where(active: true) }
  scope :for_user, ->(user) { where(user: user) }

  def formatted_balance
    ActionController::Base.helpers.number_to_currency(balance, unit: "R$", separator: ",", delimiter: ".")
  end
end
