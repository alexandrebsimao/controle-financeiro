# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

class GeminiService
  API_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"
  DEFAULT_MODEL = "gemini-3.5-flash"

  class ApiError < StandardError; end

  def self.configured?(api_key = nil)
    api_key.presence || ENV["GEMINI_API_KEY"].present?
  end

  def self.ping(api_key: nil, model: nil)
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    chat(prompt: "ping", model: model, api_key: api_key, temperature: 0.0)
    elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time).round(2)
    { success: true, latency: elapsed, model: model.presence || ENV["GEMINI_MODEL"].presence || DEFAULT_MODEL }
  rescue StandardError => e
    { success: false, error: e.message }
  end

  def self.chat(prompt:, system_prompt: nil, model: nil, api_key: nil, temperature: 0.3, inline_data: nil)
    new.chat(prompt: prompt, system_prompt: system_prompt, model: model, api_key: api_key, temperature: temperature, inline_data: inline_data)
  end

  def chat(prompt:, system_prompt: nil, model: nil, api_key: nil, temperature: 0.3, inline_data: nil)
    effective_key = api_key.presence || ENV["GEMINI_API_KEY"].to_s.strip
    if effective_key.blank?
      raise ApiError, "Chave da API do Google Gemini (GEMINI_API_KEY) não está configurada no sistema. Configure-a no arquivo .env ou nas Configurações de IA."
    end

    raw_model = model.presence || ENV["GEMINI_MODEL"].presence || DEFAULT_MODEL
    selected_model = raw_model.sub(%r{\Amodels/}, "")
    
    uri = URI.parse("#{API_BASE_URL}/#{selected_model}:generateContent?key=#{effective_key}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 15
    http.read_timeout = 60

    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"
    request["x-goog-api-key"] = effective_key

    user_parts = []
    if inline_data.present?
      user_parts << {
        inlineData: {
          mimeType: inline_data[:mime_type] || inline_data[:mimeType] || "application/pdf",
          data: inline_data[:data]
        }
      }
    end
    user_parts << { text: prompt } if prompt.present?

    payload = {
      contents: [
        {
          role: "user",
          parts: user_parts
        }
      ],
      generationConfig: {
        temperature: temperature,
        maxOutputTokens: 8192
      }
    }

    if system_prompt.present?
      payload[:system_instruction] = {
        parts: [{ text: system_prompt }]
      }
    end

    request.body = payload.to_json

    response = http.request(request)
    parsed_body = begin
      JSON.parse(response.body)
    rescue StandardError
      {}
    end

    if response.is_a?(Net::HTTPSuccess)
      candidates = parsed_body["candidates"] || []
      first_candidate = candidates.first || {}
      parts = first_candidate.dig("content", "parts") || []
      
      content = parts.map { |p| p["text"] }.compact.join("\n").strip
      if content.blank?
        finish_reason = first_candidate["finishReason"]
        raise ApiError, "Resposta vazia retornada pelo Gemini (finish_reason: #{finish_reason})"
      end

      content
    else
      error_message = parsed_body.dig("error", "message") || response.message
      raise ApiError, "Erro retornado pelo Gemini: #{error_message}"
    end
  rescue SocketError, Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED => e
    raise ApiError, "Falha de conexão com a API do Gemini: #{e.message}"
  end
end
