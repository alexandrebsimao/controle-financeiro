# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

class GroqService
  API_URL = "https://api.groq.com/openai/v1/chat/completions"
  DEFAULT_MODEL = "openai/gpt-oss-120b"

  class ApiError < StandardError; end

  def self.configured?(api_key = nil)
    api_key.presence || ENV["GROQ_API_KEY"].present?
  end

  def self.ping(api_key: nil, model: nil)
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    chat(prompt: "ping", model: model, api_key: api_key, temperature: 0.0)
    elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time).round(2)
    { success: true, latency: elapsed, model: model.presence || ENV["GROQ_MODEL"].presence || DEFAULT_MODEL }
  rescue StandardError => e
    { success: false, error: e.message }
  end

  def self.chat(prompt:, system_prompt: nil, model: nil, api_key: nil, temperature: 0.3)
    new.chat(prompt: prompt, system_prompt: system_prompt, model: model, api_key: api_key, temperature: temperature)
  end

  def chat(prompt:, system_prompt: nil, model: nil, api_key: nil, temperature: 0.3)
    effective_key = api_key.presence || ENV["GROQ_API_KEY"].to_s.strip
    if effective_key.blank?
      raise ApiError, "Chave da API do Groq (GROQ_API_KEY) não está configurada no sistema. Configure-a no arquivo .env ou nas Configurações de IA."
    end

    selected_model = model.presence || ENV["GROQ_MODEL"].presence || DEFAULT_MODEL
    uri = URI.parse(API_URL)

    messages = []
    messages << { role: "system", content: system_prompt } if system_prompt.present?
    messages << { role: "user", content: prompt }

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 15
    http.read_timeout = 60

    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{effective_key}"

    payload = {
      model: selected_model,
      messages: messages,
      temperature: temperature,
      max_tokens: 8000
    }

    request.body = payload.to_json

    response = http.request(request)
    parsed_body = begin
      JSON.parse(response.body)
    rescue StandardError
      {}
    end

    if response.is_a?(Net::HTTPSuccess)
      content = parsed_body.dig("choices", 0, "message", "content")
      raise ApiError, "Resposta vazia retornada pela API do Groq" if content.blank?

      content
    else
      error_message = parsed_body.dig("error", "message") || response.message
      raise ApiError, "Erro retornado pelo Groq: #{error_message}"
    end
  rescue SocketError, Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED => e
    raise ApiError, "Falha de conexão com a API do Groq: #{e.message}"
  end
end
