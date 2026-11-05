# frozen_string_literal: true

class FinancialInsightsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_insight, only: %i[show destroy]

  def index
    @insights = current_user.financial_insights.recent.page(params[:page]).per(10)
    @latest_insight = @insights.first
    @providers = AiService.providers
    @current_provider = current_user.preferred_ai_provider
    @groq_configured = GroqService.configured?
    @gemini_configured = GeminiService.configured?
  end

  def show
  end

  def create
    chosen_provider = params[:provider].presence || current_user.preferred_ai_provider
    
    if params[:save_as_default] == "1" && current_user.respond_to?(:preferred_ai_provider=)
      current_user.update(preferred_ai_provider: chosen_provider)
    end

    unless AiService.configured?(chosen_provider)
      provider_name = chosen_provider == "gemini" ? "Google Gemini (GEMINI_API_KEY)" : "Groq (GROQ_API_KEY)"
      return redirect_to financial_insights_path, alert: "A chave de API para #{provider_name} ainda não foi definida no arquivo .env."
    end

    insight = FinancialAnalysisService.new(current_user, provider: chosen_provider).call
    provider_label = chosen_provider == "gemini" ? "Google Gemini" : "Groq"
    redirect_to financial_insight_path(insight), notice: "Nova análise financeira gerada com sucesso via #{provider_label}!"
  rescue GroqService::ApiError, GeminiService::ApiError, AiService::ConfigurationError => e
    redirect_to financial_insights_path, alert: e.message
  rescue StandardError => e
    Rails.logger.error("[FinancialInsightsController] Erro: #{e.class} - #{e.message}")
    redirect_to financial_insights_path, alert: "Não foi possível gerar a análise no momento: #{e.message}"
  end

  def update_preference
    new_provider = params[:provider].to_s.downcase
    if %w[groq gemini].include?(new_provider)
      current_user.update(preferred_ai_provider: new_provider) if current_user.respond_to?(:preferred_ai_provider=)
      provider_name = new_provider == "gemini" ? "Google Gemini" : "Groq"
      redirect_to financial_insights_path, notice: "Provedor padrão de IA alterado para #{provider_name}!"
    else
      redirect_to financial_insights_path, alert: "Provedor inválido."
    end
  end

  def destroy
    @insight.destroy
    redirect_to financial_insights_path, notice: "Análise excluída com sucesso."
  end

  private

  def set_insight
    @insight = current_user.financial_insights.find(params[:id])
  end
end
