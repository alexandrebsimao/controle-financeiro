# frozen_string_literal: true

class FinancialAnalysisJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    FinancialAnalysisService.new(user).call
  rescue StandardError => e
    Rails.logger.error("[FinancialAnalysisJob] Erro ao gerar análise para usuário #{user_id}: #{e.message}")
    raise e
  end
end
