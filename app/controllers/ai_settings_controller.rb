# frozen_string_literal: true

class AiSettingsController < ApplicationController
  before_action :authenticate_user!

  def show
    @providers = AiService.providers(current_user)
    @current_provider = AiService.default_provider(current_user)
    @user = current_user
  end

  def update
    permitted_params = params.require(:user).permit(
      :preferred_ai_provider,
      :groq_model,
      :gemini_model,
      :custom_groq_api_key,
      :custom_gemini_api_key
    )

    # Limpar chaves em branco para não salvar strings vazias
    permitted_params[:custom_groq_api_key] = nil if permitted_params[:custom_groq_api_key].blank?
    permitted_params[:custom_gemini_api_key] = nil if permitted_params[:custom_gemini_api_key].blank?

    if current_user.update(permitted_params)
      provider_name = current_user.preferred_ai_provider == "gemini" ? "Google Gemini" : "Groq"
      redirect_to ai_settings_path, notice: "Configurações de IA salvas! O provedor ativo no sistema agora é #{provider_name}."
    else
      @providers = AiService.providers(current_user)
      @current_provider = AiService.default_provider(current_user)
      @user = current_user
      flash.now[:alert] = "Não foi possível salvar as configurações de IA."
      render :show, status: :unprocessable_entity
    end
  end

  def test_connection
    provider = params[:provider].to_s.downcase
    result = AiService.test_connection(provider, current_user)

    provider_name = provider == "gemini" ? "Google Gemini" : "Groq"

    if result[:success]
      flash[:notice] = "✅ Conexão com #{provider_name} bem-sucedida! Latência: #{result[:latency]}s (Modelo: #{result[:model]})"
    else
      flash[:alert] = "❌ Falha ao conectar com #{provider_name}: #{result[:error]}"
    end

    redirect_to ai_settings_path
  end
end
