# frozen_string_literal: true

require "base64"
require "json"
require "ostruct"

class BankStatementImportService
  class ImportError < StandardError; end

  attr_reader :user, :bank_account, :file_content, :file_name, :provider, :model, :mark_paid

  def initialize(user:, bank_account:, file_content:, file_name: nil, provider: nil, model: nil, mark_paid: true)
    @user = user
    @bank_account = bank_account
    @file_content = file_content.is_a?(String) ? file_content : file_content.read
    @file_name = file_name || "extrato"
    @provider = provider.to_s.downcase.presence || AiService.default_provider(user)
    @model = model
    @mark_paid = (mark_paid == true || mark_paid == "1" || mark_paid == "true")
  end

  def call
    validate_inputs!

    fmt = detected_format
    inline_data = nil
    extracted_text = ""

    # 1. Extração do conteúdo dependendo do formato do arquivo
    case fmt
    when "pdf"
      extracted_text = begin
        PdfExtractorService.extract_text(file_content)
      rescue StandardError => e
        Rails.logger.warn("Falha na extração de texto via PDF::Reader: #{e.message}")
        ""
      end

      # Se o PDF não tiver texto legível (ex: escaneado/imagem)
      if extracted_text.blank? || extracted_text.strip.length < 30
        if provider == "groq"
          raise ImportError, "Não foi possível extrair texto legível deste PDF. Ele parece ser um documento escaneado/imagem. O provedor Groq requer texto digital. Por favor, selecione o Google Gemini, que possui visão computacional nativa para ler extratos escaneados."
        elsif provider == "gemini"
          inline_data = {
            mime_type: "application/pdf",
            data: Base64.strict_encode64(file_content)
          }
        end
      end
    when "ofx", "csv", "text"
      extracted_text = clean_text_content(file_content)
      if extracted_text.blank?
        raise ImportError, "O arquivo #{fmt.upcase} fornecido está vazio ou não pôde ser lido."
      end
    end

    # 2. Preparar contexto de categorias e conta bancária
    categories_context = user_categories_for_prompt
    prompt = build_prompt(extracted_text, categories_context, inline_data.present?, fmt)

    # 3. Chamar o serviço de IA
    system_prompt = <<~PROMPT
      Você é um assistente financeiro especialista em extratos bancários brasileiros (PDF, OFX, CSV de bancos como Nubank, Inter, Itaú, Bradesco, etc.).
      Sua tarefa é extrair com precisão cirúrgica todas as movimentações financeiras do extrato e retornar EXCLUSIVAMENTE um array JSON de objetos válidos, sem texto introdutório, sem blocos de markdown adicionais e sem explicações.
    PROMPT

    ai_response = begin
      AiService.chat(
        prompt: prompt,
        system_prompt: system_prompt,
        provider: provider,
        model: model,
        temperature: 0.1,
        user: user,
        inline_data: inline_data
      )
    rescue StandardError => e
      raise ImportError, "Erro na comunicação com a IA (#{provider.to_s.titleize}): #{e.message}"
    end

    # 4. Processar e estruturar o JSON de resposta
    raw_content = ai_response[:content]
    parsed_json = parse_ai_json(raw_content)

    unless parsed_json.is_a?(Array)
      raise ImportError, "A IA não retornou uma lista válida de transações. Tente novamente ou use outro provedor."
    end

    # 5. Normalizar, validar e detectar duplicidades
    items = process_and_enrich_items(parsed_json)

    if items.empty?
      raise ImportError, "Nenhuma movimentação financeira válida foi identificada no arquivo de extrato enviado."
    end

    # 6. Resumo financeiro da importação
    total_income = items.select { |i| i[:transaction_type] == "income" }.sum { |i| i[:amount_numeric] }
    total_expense = items.select { |i| i[:transaction_type] == "expense" }.sum { |i| i[:amount_numeric] }
    net_balance = total_income - total_expense

    Result.new(
      success?: true,
      items: items,
      total_items: items.size,
      total_income: total_income,
      total_expense: total_expense,
      net_balance: net_balance,
      bank_account: bank_account,
      file_format: fmt.upcase,
      provider_used: ai_response[:provider],
      provider_name: ai_response[:provider_name],
      provider_badge: ai_response[:provider_badge],
      model_used: ai_response[:model_used],
      mark_paid: mark_paid
    )
  end

  Result = Struct.new(
    :success?,
    :items,
    :total_items,
    :total_income,
    :total_expense,
    :net_balance,
    :bank_account,
    :file_format,
    :provider_used,
    :provider_name,
    :provider_badge,
    :model_used,
    :mark_paid,
    keyword_init: true
  )

  private

  def detected_format
    ext = File.extname(file_name.to_s).downcase.delete(".")
    return "pdf" if ext == "pdf" || file_content.start_with?("%PDF")
    return "ofx" if ext == "ofx" || file_content.include?("<OFX>") || file_content.include?("<STMTTRN>")
    return "csv" if ext == "csv"

    if file_content.start_with?("%PDF")
      "pdf"
    elsif file_content.include?("<OFX>") || file_content.include?("<STMTTRN>")
      "ofx"
    elsif file_content.include?(",") || file_content.include?(";")
      "csv"
    else
      "text"
    end
  end

  def clean_text_content(raw)
    content = raw.to_s
    if content.dup.force_encoding("UTF-8").valid_encoding?
      content.dup.force_encoding("UTF-8")
    else
      content.encode("UTF-8", "ISO-8859-1", invalid: :replace, undef: :replace, replace: "")
    end.sub(/\A\xEF\xBB\xBF/, "")
  end

  def validate_inputs!
    raise ImportError, "Nenhum arquivo de extrato foi fornecido." if file_content.blank?
    raise ImportError, "Selecione uma conta bancária de destino." if bank_account.blank?

    unless AiService.configured?(provider, user)
      raise ImportError, "O provedor de IA selecionado (#{provider.to_s.titleize}) não está configurado com chave de API válida."
    end
  end

  def user_categories_for_prompt
    categories = Category.for_user(user).order(:name).map do |cat|
      { id: cat.id, name: cat.full_name, type: cat.transaction_type }
    end
    categories.to_json
  end

  def build_prompt(extracted_text, categories_json, using_binary_pdf, fmt)
    format_instructions = case fmt
    when "ofx"
      <<~OFX_INST
        Formato do arquivo: OFX (Open Financial Exchange).
        - Cada movimentação está contida em tags <STMTTRN>.
        - <TRNTYPE>: DEBIT indica saída/despesa ("expense"), CREDIT indica entrada/receita ("income").
        - <TRNAMT>: Valor da transação (converta sempre para número decimal positivo no campo amount).
        - <DTPOSTED>: Data no formato AAAAMMDD ou AAAAMMDDHHMMSS. Converta para AAAA-MM-DD.
        - <MEMO> ou <NAME>: Título e detalhes do lançamento (ex: Pix enviado, compra débito, salário).
        - <FITID>: Código identificador único (guarde-o no campo "notes").
      OFX_INST
    when "csv"
      <<~CSV_INST
        Formato do arquivo: CSV (ex: Nubank, Inter, etc. delimitado por vírgula ou ponto-e-vírgula).
        - Geralmente possui colunas como: Data, Valor, Identificador / Título, Descrição / Detalhes.
        - Se o valor for negativo (ex: -50.00 ou -32,50) ou marcado com "D", classifique como "expense" (saída) e informe o valor como positivo.
        - Se o valor for positivo ou marcado com "C", classifique como "income" (entrada).
      CSV_INST
    else
      <<~PDF_INST
        Formato do arquivo: PDF de Extrato Bancário.
      PDF_INST
    end

    content_instruction = if using_binary_pdf
      "Analise o documento PDF do extrato bancário em anexo."
    else
      <<~TEXT
        Analise os dados brutos do extrato bancário abaixo:
        ```
        #{extracted_text}
        ```
      TEXT
    end

    <<~PROMPT
      #{content_instruction}

      #{format_instructions}

      Conta bancária de destino: #{bank_account.name} (Saldo atual: #{bank_account.formatted_balance rescue "R$ 0,00"}).

      Categorias disponíveis no sistema do usuário:
      #{categories_json}

      INSTRUÇÕES CRÍTICAS PARA EXTRAÇÃO:
      1. Extraia APENAS movimentações financeiras reais (entradas e saídas de dinheiro).
      2. REGRA DE EXCLUSÃO DE SALDOS E TOTAIS:
         - NUNCA inclua linhas de saldo, tais como: "Saldo Anterior", "Saldo Inicial", "Saldo do Dia", "SDO ATUAL", "Saldo Final", "Total de Entradas", "Total de Saídas", "Limite Cheque Especial", "Saldo Disponível", ou rendimentos de saldo diário se forem meramente demonstrativos.
      3. CLASSIFICAÇÃO:
         - "expense": qualquer saída, pagamento, débito, Pix enviado, compra no débito, saque, transferência enviada, tarifa bancária, IOF.
         - "income": qualquer entrada, recebimento, crédito, Pix recebido, salário, depósito, transferência recebida, estorno a favor do cliente.
      4. VALOR (amount):
         - Número decimal positivo sempre com ponto (ex: 45.90, e NÃO -45.90).
      5. DATA (due_date):
         - Formato AAAA-MM-DD (ex: 2026-03-15). Se o extrato contiver apenas dia/mês (ex: 15/03), utilize o ano do extrato ou 2026.
      6. TÍTULO (title):
         - Título conciso, limpo e compreensível para humanos (ex: "Pix Enviado - Mariana Silva", "Salário Mensal", "Farmácia São João", "Tarifa Bancária").
         - Evite códigos de barra gigantescos ou números de controle no título; guarde esses detalhes no campo "notes".
      7. MÉTODO DE PAGAMENTO (payment_method):
         - Escolha obrigatoriamente um dentre: "pix", "ted", "boleto", "debit_card", "transfer", "other".
      8. CATEGORIA (category_id e category_name):
         - Escolha o 'id' e 'name' da categoria mais compatível da lista de categorias fornecida. Se nenhuma fizer sentido, use null.
      9. NOTAS (notes):
         - Dados complementares da linha do extrato (documento, canal, autenticação, FITID).

      FORMATO DE RESPOSTA OBRIGATÓRIO (retorne EXCLUSIVAMENTE o array JSON, sem markdown e sem explicações):
      [
        {
          "due_date": "2026-03-10",
          "title": "Supermercado Exemplo",
          "transaction_type": "expense",
          "amount": 182.40,
          "payment_method": "debit_card",
          "category_id": 1,
          "category_name": "Alimentação",
          "notes": "Compra débito final 4521"
        }
      ]
    PROMPT
  end

  def parse_ai_json(text)
    clean_text = text.to_s.strip
    clean_text = clean_text.sub(/\A```(?:json)?\s*/i, "").sub(/\s*```\z/i, "").strip
    
    if clean_text =~ /(\[[\s\S]*\])/
      clean_text = $1
    end

    JSON.parse(clean_text)
  rescue JSON::ParserError => e
    Rails.logger.error("Erro ao analisar JSON retornado pela IA: #{e.message}\nConteúdo bruto: #{text}")
    raise ImportError, "A resposta da IA não pôde ser interpretada como JSON válido. Detalhes: #{e.message}"
  end

  def process_and_enrich_items(raw_items)
    valid_categories_ids = Category.for_user(user).pluck(:id)
    
    recent_transactions = user.transactions
                              .where(bank_account_id: bank_account.id)
                              .order(due_date: :desc)
                              .limit(500)
                              .to_a

    enriched = []

    raw_items.each_with_index do |raw, index|
      row_id = index + 1
      title = raw["title"].to_s.strip
      raw_amount = raw["amount"].to_f.abs
      type_str = raw["transaction_type"].to_s.downcase.strip
      type = if %w[investment investimento aporte fundos].include?(type_str)
               "investment"
             elsif %w[income entrada receita].include?(type_str)
               "income"
             else
               "expense"
             end

      date = parse_date(raw["due_date"]) || Date.today

      next if title.blank? || raw_amount <= 0.0

      cat_id = raw["category_id"].to_i
      category_id = valid_categories_ids.include?(cat_id) ? cat_id : nil
      category_name = raw["category_name"].presence || (category_id ? Category.find_by(id: category_id)&.name : nil)

      method = raw["payment_method"].to_s.downcase.strip
      payment_method = Transaction::PAYMENT_METHODS.key?(method) ? method : "other"

      duplicate = detect_duplicate(recent_transactions, date, raw_amount, type, title)

      enriched << {
        row_id: row_id,
        title: title,
        amount: sprintf("%.2f", raw_amount),
        amount_numeric: raw_amount,
        transaction_type: type,
        due_date: date.strftime("%Y-%m-%d"),
        paid: mark_paid,
        paid_at: (mark_paid ? date.strftime("%Y-%m-%d") : nil),
        payment_method: payment_method,
        category_id: category_id,
        category_name: category_name,
        notes: raw["notes"].to_s.strip.presence,
        is_duplicate: duplicate.present?,
        duplicate_reason: duplicate ? "Já existe transação idêntica/similar registrada (#{duplicate.title} - #{duplicate.formatted_amount} em #{duplicate.due_date.strftime('%d/%m/%Y')})" : nil,
        selected: duplicate.blank?
      }.with_indifferent_access
    end

    enriched
  end

  def detect_duplicate(transactions, date, amount, type, title)
    transactions.find do |t|
      t.due_date == date &&
        (t.amount - amount).abs < 0.01 &&
        t.transaction_type == type
    end
  end

  def parse_date(value)
    text = value.to_s.strip
    return nil if text.blank?

    # Trata data de OFX compacta: AAAAMMDD...
    if text =~ /\A(\d{4})(\d{2})(\d{2})/
      return Date.new($1.to_i, $2.to_i, $3.to_i)
    end

    Date.parse(text)
  rescue ArgumentError, Date::Error
    nil
  end
end
