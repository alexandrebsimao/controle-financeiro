# frozen_string_literal: true

class AiService
  PROVIDERS = {
    "groq" => {
      id: "groq",
      name: "Groq (LPU Ultra Rápido)",
      short_name: "Groq",
      badge: "⚡ Groq",
      default_model: ENV.fetch("GROQ_MODEL", GroqService::DEFAULT_MODEL),
      available_models: ["openai/gpt-oss-120b", "openai/gpt-oss-20b"],
      description: "Processamento ultra veloz via chips LPU com alta capacidade de raciocínio lógico.",
      service_class: GroqService
    },
    "gemini" => {
      id: "gemini",
      name: "Google Gemini",
      short_name: "Gemini",
      badge: "✨ Google Gemini",
      default_model: ENV.fetch("GEMINI_MODEL", GeminiService::DEFAULT_MODEL),
      available_models: ["gemini-3.5-flash", "gemini-3.5-flash-lite"],
      description: "Inteligência de ponta do Google com ampla janela de contexto e alta precisão analítica.",
      service_class: GeminiService
    }
  }.freeze

  class ConfigurationError < StandardError; end

  def self.providers(user = nil)
    active_prov = default_provider(user)
    PROVIDERS.values.map do |p|
      configured = configured?(p[:id], user)
      model = if user
                p[:id] == "gemini" ? user.effective_gemini_model : user.effective_groq_model
              else
                p[:default_model]
              end

      p.merge(
        configured: configured,
        active_model: model,
        is_active: (p[:id] == active_prov)
      )
    end
  end

  def self.configured?(provider_id, user = nil)
    provider_info = PROVIDERS[provider_id.to_s.downcase]
    return false unless provider_info

    if user
      key = provider_id.to_s.downcase == "gemini" ? user.effective_gemini_api_key : user.effective_groq_api_key
      return true if key.present?
    end

    provider_info[:service_class].configured?
  end

  def self.default_provider(user = nil)
    user_choice = user.try(:preferred_ai_provider).to_s.downcase.presence
    return user_choice if user_choice.present? && configured?(user_choice, user)

    env_choice = ENV["AI_PROVIDER"].to_s.downcase.presence
    return env_choice if env_choice.present? && configured?(env_choice, user)

    return "gemini" if configured?("gemini", user)
    return "groq" if configured?("groq", user)

    "groq"
  end

  def self.test_connection(provider, user = nil)
    provider_id = provider.to_s.downcase
    provider_info = PROVIDERS[provider_id]
    return { success: false, error: "Provedor desconhecido" } unless provider_info

    key = if user
            provider_id == "gemini" ? user.effective_gemini_api_key : user.effective_groq_api_key
          end
    model = if user
              provider_id == "gemini" ? user.effective_gemini_model : user.effective_groq_model
            end

    provider_info[:service_class].ping(api_key: key, model: model)
  end

  def self.chat(prompt:, system_prompt: nil, provider: nil, model: nil, temperature: 0.3, user: nil, inline_data: nil)
    chosen_provider = provider.to_s.downcase.presence || default_provider(user)
    provider_info = PROVIDERS[chosen_provider]

    unless provider_info
      raise ConfigurationError, "Provedor de IA desconhecido: #{chosen_provider}. Escolha entre 'groq' ou 'gemini'."
    end

    service_class = provider_info[:service_class]
    api_key = if user
                chosen_provider == "gemini" ? user.effective_gemini_api_key : user.effective_groq_api_key
              end

    unless service_class.configured?(api_key)
      raise ConfigurationError, "O provedor #{provider_info[:name]} selecionado não possui chave de API configurada no sistema (.env ou Configurações de IA)."
    end

    model_to_use = model.presence || (user ? (chosen_provider == "gemini" ? user.effective_gemini_model : user.effective_groq_model) : nil) || provider_info[:default_model]

    chat_kwargs = {
      prompt: prompt,
      system_prompt: system_prompt,
      model: model_to_use,
      api_key: api_key,
      temperature: temperature
    }
    chat_kwargs[:inline_data] = inline_data if chosen_provider == "gemini" && inline_data.present?

    content = service_class.chat(**chat_kwargs)

    {
      content: content,
      provider: chosen_provider,
      provider_name: provider_info[:name],
      provider_badge: provider_info[:badge],
      model_used: model_to_use
    }
  end
end
