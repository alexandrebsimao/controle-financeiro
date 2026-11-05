class Category < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :parent, class_name: "Category", optional: true

  has_many :children, class_name: "Category", foreign_key: :parent_id, dependent: :destroy
  has_many :category_keywords, dependent: :destroy
  has_many :transactions
  has_many :credit_card_purchases

  TRANSACTION_TYPES = %w[income expense investment both].freeze

  validates :name, presence: true
  validates :transaction_type, inclusion: { in: TRANSACTION_TYPES }

  scope :system_defaults, -> { where(user_id: nil) }
  scope :for_user, ->(user) { where(user: user).or(where(user_id: nil)) }
  scope :top_level, -> { where(parent_id: nil) }
  scope :income_categories, -> { where(transaction_type: %w[income both]) }
  scope :expense_categories, -> { where(transaction_type: %w[expense both]) }
  scope :investment_categories, -> { where(transaction_type: %w[investment both]) }

  def full_name
    parent ? "#{parent.name} > #{name}" : name
  end
end
