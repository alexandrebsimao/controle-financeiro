# frozen_string_literal: true

class FinancialInsight < ApplicationRecord
  belongs_to :user

  validates :title, presence: true
  validates :period, presence: true
  validates :content, presence: true

  scope :recent, -> { order(created_at: :desc) }

  def formatted_date
    created_at.strftime("%d/%m/%Y às %H:%M")
  end

  def formatted_period
    period.presence || created_at.strftime("%B/%Y")
  end

  def provider
    if has_attribute?(:ai_provider) && self[:ai_provider].present?
      self[:ai_provider]
    elsif model_used.to_s.downcase.include?("gemini")
      "gemini"
    else
      "groq"
    end
  end

  def provider_badge
    case provider
    when "gemini"
      "✨ Google Gemini"
    else
      "⚡ Groq"
    end
  end

  def total_income
    (raw_metrics&.dig("current_month_forecast", "total_projected_income") || raw_metrics&.dig("current_month", "income") || 0).to_f
  end

  def total_expenses
    (raw_metrics&.dig("current_month_forecast", "total_projected_operational_expenses") || raw_metrics&.dig("current_month", "operational_expenses") || raw_metrics&.dig("current_month", "expenses") || 0).to_f
  end

  def total_investments
    (raw_metrics&.dig("current_month_forecast", "investments") || raw_metrics&.dig("current_month", "investments") || 0).to_f
  end

  def net_savings
    (raw_metrics&.dig("current_month_forecast", "projected_operational_balance") || raw_metrics&.dig("current_month", "net_operational_balance") || (total_income - total_expenses)).to_f
  end

  def savings_rate
    return 0.0 if total_income.zero?

    ((net_savings / total_income) * 100).round(1)
  end

  def timing_analysis
    raw_metrics&.dig("cash_flow_timing_analysis") || {}
  end

  def early_commitments
    timing_analysis["early_month_commitments_until_day_19"].to_f
  end

  def working_capital_buffer
    timing_analysis["recommended_working_capital_buffer"].to_f
  end
end
