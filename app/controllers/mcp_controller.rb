# frozen_string_literal: true

require "digest"

class McpController < ActionController::API
  before_action :authenticate_mcp!, except: :options

  def show
    render json: {
      name: FinancesMcpHandler::SERVER_INFO.fetch(:name),
      version: FinancesMcpHandler::SERVER_INFO.fetch(:version),
      transport: "streamable_http",
      endpoint: "/mcp"
    }
  end

  def options
    head :no_content
  end

  def create
    message = JSON.parse(request.raw_post)
    response = FinancesMcpHandler.new.handle(message)

    if response
      render json: response
    else
      head :accepted
    end
  rescue JSON::ParserError
    render json: {
      jsonrpc: "2.0",
      id: nil,
      error: {
        code: -32700,
        message: "Invalid JSON"
      }
    }, status: :bad_request
  end

  private

  def authenticate_mcp!
    expected_token = ENV["MCP_AUTH_TOKEN"].to_s
    return render_auth_error("MCP_AUTH_TOKEN is not configured", :service_unavailable) if expected_token.blank?

    provided_token = bearer_token || request.headers["X-MCP-Token"].to_s || params[:token].to_s
    return render_auth_error("Unauthorized", :unauthorized) if provided_token.blank?

    valid = ActiveSupport::SecurityUtils.secure_compare(
      Digest::SHA256.hexdigest(provided_token),
      Digest::SHA256.hexdigest(expected_token)
    )

    render_auth_error("Unauthorized", :unauthorized) unless valid
  end

  def bearer_token
    authorization = request.headers["Authorization"].to_s
    return unless authorization.start_with?("Bearer ")

    authorization.delete_prefix("Bearer ").strip
  end

  def render_auth_error(message, status)
    render json: {
      jsonrpc: "2.0",
      id: nil,
      error: {
        code: -32001,
        message: message
      }
    }, status: status
  end
end
