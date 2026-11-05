class Recurrence < ApplicationRecord
  belongs_to :user
  belongs_to :bank_account
  belongs_to :category, optional: true

  has_many :transactions, dependent: :destroy

  FREQUENCIES = %w[daily weekly monthly yearly].freeze
  TRANSACTION_TYPES = %w[income expense investment].freeze
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

  validates :title, presence: true
  validates :transaction_type, inclusion: { in: TRANSACTION_TYPES }
  validates :frequency, inclusion: { in: FREQUENCIES }
  validates :amount, numericality: { greater_than: 0 }
  validates :start_date, presence: true
  validates :interval, numericality: { greater_than: 0 }

  scope :active, -> { where(active: true) }

  def next_due_date
    return nil unless active

    case frequency
    when "daily"
      start_date + (occurrences_generated * interval).days
    when "weekly"
      start_date + (occurrences_generated * interval).weeks
    when "monthly"
      start_date + (occurrences_generated * interval).months
    when "yearly"
      start_date + (occurrences_generated * interval).years
    end
  end

  def finished?
    return true unless active
    return true if end_date && next_due_date && next_due_date > end_date
    return true if total_occurrences && occurrences_generated >= total_occurrences
    false
  end

  def infinite?
    end_date.nil? && total_occurrences.nil?
  end

  def income?
    transaction_type == "income"
  end

  def expense?
    transaction_type == "expense"
  end

  def investment?
    transaction_type == "investment"
  end

  # Retorna as mudanças críticas que afetam futuros cálculos
  def critical_changes
    critical_attributes = %w[frequency interval start_date total_occurrences end_date]
    changes.select { |k, _| critical_attributes.include?(k) }
  end

  # Verifica se há mudanças que afetam a geração
  def has_critical_changes?
    critical_changes.any?
  end

  # Total de ocorrências restantes a gerar
  def remaining_occurrences
    return 'Infinita' unless total_occurrences
    remaining = total_occurrences - occurrences_generated
    remaining > 0 ? remaining : 0
  end

  # Próxima data que será gerada
  def upcoming_due_date
    next_due_date
  end
end
