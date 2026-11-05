#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

ENV["RAILS_ENV"] ||= "development"
require_relative "../config/environment"

class FinancesMcpStdioServer
  def initialize(handler: FinancesMcpHandler.new)
    @handler = handler
  end

  def run
    while (message = read_message)
      response = @handler.handle(message)
      write_message(response) if response
    end
  rescue Interrupt
    nil
  end

  private

  def read_message
    headers = {}

    while (line = $stdin.gets)
      line = line.chomp
      break if line.empty?

      name, value = line.split(":", 2)
      headers[name.downcase] = value.strip if name && value
    end

    return nil if headers.empty? && $stdin.eof?

    length = headers.fetch("content-length").to_i
    JSON.parse($stdin.read(length))
  end

  def write_message(payload)
    body = JSON.generate(payload)
    $stdout.write("Content-Length: #{body.bytesize}\r\n\r\n#{body}")
    $stdout.flush
  end
end

FinancesMcpStdioServer.new.run
