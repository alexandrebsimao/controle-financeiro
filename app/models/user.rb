class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :bank_accounts, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :transactions, dependent: :destroy
  has_many :recurrences, dependent: :destroy
  has_many :credit_cards, dependent: :destroy
  has_many :active_credit_cards, -> { where(active: true) }, class_name: "CreditCard"
  has_many :credit_card_invoices, through: :credit_cards
  has_many :active_credit_card_invoices, through: :active_credit_cards, source: :credit_card_invoices
  has_many :financial_insights, dependent: :destroy

  validates :name, presence: true

  def preferred_ai_provider
    if has_attribute?(:preferred_ai_provider) && self[:preferred_ai_provider].present?
      self[:preferred_ai_provider]
    else
      ENV.fetch("AI_PROVIDER", "groq")
    end
  end

  def effective_groq_api_key
    if has_attribute?(:custom_groq_api_key) && custom_groq_api_key.present?
      custom_groq_api_key
    else
      ENV["GROQ_API_KEY"]
    end
  end

  def effective_gemini_api_key
    if has_attribute?(:custom_gemini_api_key) && custom_gemini_api_key.present?
      custom_gemini_api_key
    else
      ENV["GEMINI_API_KEY"]
    end
  end

  def effective_groq_model
    if has_attribute?(:groq_model) && groq_model.present?
      groq_model
    else
      ENV.fetch("GROQ_MODEL", GroqService::DEFAULT_MODEL)
    end
  end

  def effective_gemini_model
    if has_attribute?(:gemini_model) && gemini_model.present?
      gemini_model
    else
      ENV.fetch("GEMINI_MODEL", GeminiService::DEFAULT_MODEL)
    end
  end
end

