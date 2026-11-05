# frozen_string_literal: true

require "pdf-reader"
require "stringio"

class PdfExtractorService
  class ExtractionError < StandardError; end

  def self.extract_text(file_or_content)
    new(file_or_content).extract_text
  end

  def initialize(file_or_content)
    @source = if file_or_content.is_a?(String)
                if file_or_content.start_with?("%PDF")
                  StringIO.new(file_or_content)
                elsif File.exist?(file_or_content)
                  file_or_content
                else
                  StringIO.new(file_or_content)
                end
              elsif file_or_content.respond_to?(:path) && File.exist?(file_or_content.path)
                file_or_content.path
              elsif file_or_content.respond_to?(:read)
                StringIO.new(file_or_content.read)
              else
                file_or_content
              end
  end

  def extract_text
    reader = PDF::Reader.new(@source)
    pages_text = []

    reader.pages.each_with_index do |page, idx|
      raw_page_text = page.text.to_s.strip
      next if raw_page_text.blank?

      # Normalize spaces and blank lines
      clean_page_text = raw_page_text.gsub(/[ \t]+/, " ").gsub(/\n{3,}/, "\n\n")
      pages_text << "--- Página #{idx + 1} ---\n#{clean_page_text}"
    end

    pages_text.join("\n\n")
  rescue PDF::Reader::MalformedPDFError => e
    raise ExtractionError, "O arquivo PDF é inválido ou está corrompido: #{e.message}"
  rescue PDF::Reader::UnsupportedFeatureError => e
    raise ExtractionError, "Recurso não suportado no PDF (ex: criptografia por senha): #{e.message}"
  rescue StandardError => e
    raise ExtractionError, "Erro ao processar arquivo PDF: #{e.message}"
  end
end
