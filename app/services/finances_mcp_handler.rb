# frozen_string_literal: true

require "bigdecimal"
require "csv"
require "date"
require "digest"
require "json"
require "pathname"

class FinancesMcpHandler
  SERVER_INFO = {
    name: "finances-bank-statements",
    version: "0.1.0"
  }.freeze

  PROTOCOL_VERSION = "2024-11-05"

  def handle(message)
    id = message["id"]

    case message["method"]
    when "initialize"
      response(id, {
        protocolVersion: PROTOCOL_VERSION,
        capabilities: {
          tools: {}
        },
        serverInfo: SERVER_INFO
      })
    when "notifications/initialized"
      nil
    when "tools/list"
      response(id, { tools: tool_definitions })
    when "tools/call"
      call_tool(id, message.fetch("params", {}))
    when "resources/list"
      response(id, { resources: [] })
    when "prompts/list"
      response(id, { prompts: [] })
    else
      error_response(id, -32601, "Unknown method: #{message["method"]}")
    end
  rescue StandardError => e
    Rails.logger.error("#{e.class}: #{e.message}\n#{e.backtrace&.first(8)&.join("\n")}") if defined?(Rails)
    error_response(id, -32000, e.message)
  end

  private

  def call_tool(id, params)
    name = params.fetch("name")
    args = params.fetch("arguments", {})

    result =
      case name
      when "finances_context"
        finances_context(args)
      when "analyze_statement_csv"
        analyze_statement_csv(args)
      when "import_statement_csv"
        import_statement_csv(args)
      when "suggest_de_para"
        suggest_de_para(args)
      when "upsert_de_para_keyword"
        upsert_de_para_keyword(args)
      else
        raise ArgumentError, "Unknown tool: #{name}"
      end

    response(id, {
      content: [
        {
          type: "text",
          text: JSON.pretty_generate(json_ready(result))
        }
      ]
    })
  end

  def finances_context(args)
    user = find_user(args)

    {
      user: user_payload(user),
      bank_accounts: BankAccount.for_user(user).order(:name).map { |account| bank_account_payload(account) },
      categories: Category.for_user(user).order(:name).map { |category| category_payload(category) },
      category_keywords: CategoryKeyword
        .joins(:category)
        .where(categories: { user_id: [nil, user.id] })
        .order(priority: :desc, keyword: :asc)
        .limit(integer_arg(args, "keyword_limit", 200))
        .map { |keyword| category_keyword_payload(keyword) },
      payment_methods: Transaction::PAYMENT_METHODS
    }
  end

  def analyze_statement_csv(args)
    user = find_user(args)
    mapping = args.fetch("mapping", {})
    rows = read_statement_rows(args.fetch("file_path"), args)
    limit = integer_arg(args, "limit", 500)

    parsed = rows.first(limit).map.with_index(1) do |row, index|
      attrs = statement_attributes(row, mapping)
      category = AutoCategorizationService.new(attrs[:title], user).call

      attrs.merge(
        row_number: index,
        category: category && category_payload(category),
        idempotency_key: idempotency_key(user.id, args["bank_account_id"], attrs, row)
      )
    end

    {
      total_rows_read: rows.length,
      rows_returned: parsed.length,
      totals: totals_for(parsed),
      sample: parsed.first(integer_arg(args, "sample_size", 50))
    }
  end

  def import_statement_csv(args)
    user = find_user(args)
    bank_account = BankAccount.for_user(user).find(args.fetch("bank_account_id"))
    mapping = args.fetch("mapping", {})
    dry_run = args.fetch("dry_run", true)

    rows = read_statement_rows(args.fetch("file_path"), args)
    results = rows.map.with_index(1) do |row, index|
      attrs = statement_attributes(row, mapping)
      attrs[:idempotency_key] = idempotency_key(user.id, bank_account.id, attrs, row)

      existing = Transaction.find_by(user: user, idempotency_key: attrs[:idempotency_key])
      if existing
        import_result(index, attrs, "duplicate", existing.id, [])
      elsif dry_run
        import_result(index, attrs, "would_create", nil, [])
      else
        transaction = Transaction.new(
          user: user,
          bank_account: bank_account,
          title: attrs[:title],
          amount: attrs[:amount],
          transaction_type: attrs[:transaction_type],
          due_date: attrs[:due_date],
          paid: true,
          paid_at: attrs[:due_date],
          payment_method: attrs[:payment_method],
          notes: attrs[:notes],
          idempotency_key: attrs[:idempotency_key]
        )

        if transaction.save
          import_result(index, attrs, "created", transaction.id, [])
        else
          import_result(index, attrs, "invalid", nil, transaction.errors.full_messages)
        end
      end
    end

    {
      dry_run: dry_run,
      bank_account: bank_account_payload(bank_account),
      total_rows: rows.length,
      summary: results.group_by { |item| item[:status] }.transform_values(&:count),
      results: results
    }
  end

  def suggest_de_para(args)
    user = find_user(args)
    mapping = args.fetch("mapping", {})
    rows = read_statement_rows(args.fetch("file_path"), args)

    suggestions = rows.map do |row|
      attrs = statement_attributes(row, mapping)
      normalized = normalize_description(attrs[:title])
      category = AutoCategorizationService.new(attrs[:title], user).call

      {
        raw_title: attrs[:title],
        normalized_title: normalized,
        amount: attrs[:amount],
        transaction_type: attrs[:transaction_type],
        suggested_keyword: keyword_candidate(normalized),
        current_category: category && category_payload(category)
      }
    end

    grouped = suggestions.group_by { |item| item[:suggested_keyword] }.map do |keyword, items|
      category_counts = items.filter_map { |item| item[:current_category]&.fetch(:name) }.tally
      {
        suggested_keyword: keyword,
        occurrences: items.length,
        transaction_types: items.map { |item| item[:transaction_type] }.uniq,
        current_category_counts: category_counts,
        examples: items.first(5).map { |item| item.slice(:raw_title, :amount, :transaction_type, :current_category) }
      }
    end

    {
      total_rows_read: rows.length,
      suggestions: grouped.sort_by { |item| [-item[:occurrences], item[:suggested_keyword].to_s] }
    }
  end

  def upsert_de_para_keyword(args)
    user = find_user(args)
    category = Category.for_user(user).find(args.fetch("category_id"))
    keyword_text = args.fetch("keyword").to_s.strip
    raise ArgumentError, "keyword is required" if keyword_text.empty?

    keyword = CategoryKeyword.find_or_initialize_by(
      category: category,
      keyword: keyword_text,
      match_type: args.fetch("match_type", "contains")
    )
    keyword.priority = integer_arg(args, "priority", keyword.priority || 0)
    keyword.save!

    {
      status: keyword.previously_new_record? ? "created" : "updated",
      keyword: category_keyword_payload(keyword)
    }
  end

  def tool_definitions
    [
      {
        name: "finances_context",
        description: "Lista usuarios, contas bancarias, categorias, palavras-chave e metodos de pagamento disponiveis.",
        annotations: { readOnlyHint: true },
        inputSchema: {
          type: "object",
          properties: {
            user_id: { type: "integer" },
            user_email: { type: "string" },
            keyword_limit: { type: "integer", default: 200 }
          }
        }
      },
      {
        name: "analyze_statement_csv",
        description: "Le um extrato CSV, normaliza linhas, sugere categorias e calcula totais sem gravar dados.",
        annotations: { readOnlyHint: true },
        inputSchema: statement_schema(extra: {
          limit: { type: "integer", default: 500 },
          sample_size: { type: "integer", default: 50 }
        })
      },
      {
        name: "import_statement_csv",
        description: "Importa um extrato CSV para Transactions com idempotency_key. Use dry_run=true antes de gravar.",
        annotations: { readOnlyHint: false },
        inputSchema: statement_schema(required_bank_account: true, extra: {
          dry_run: { type: "boolean", default: true }
        })
      },
      {
        name: "suggest_de_para",
        description: "Agrupa descricoes de extrato e sugere palavras-chave para criar regras de de/para.",
        annotations: { readOnlyHint: true },
        inputSchema: statement_schema
      },
      {
        name: "upsert_de_para_keyword",
        description: "Cria ou atualiza uma palavra-chave de categoria para o de/para dos extratos.",
        annotations: { readOnlyHint: false },
        inputSchema: {
          type: "object",
          required: ["category_id", "keyword"],
          properties: {
            user_id: { type: "integer" },
            user_email: { type: "string" },
            category_id: { type: "integer" },
            keyword: { type: "string" },
            match_type: { type: "string", enum: CategoryKeyword::MATCH_TYPES, default: "contains" },
            priority: { type: "integer", default: 0 }
          }
        }
      }
    ]
  end

  def statement_schema(required_bank_account: false, extra: {})
    required = ["file_path", "mapping"]
    required << "bank_account_id" if required_bank_account

    {
      type: "object",
      required: required,
      properties: {
        user_id: { type: "integer" },
        user_email: { type: "string" },
        bank_account_id: { type: "integer" },
        file_path: { type: "string" },
        col_sep: { type: "string", default: "," },
        encoding: { type: "string", default: "bom|utf-8" },
        mapping: {
          type: "object",
          description: "Nomes das colunas do CSV. Use amount ou debit/credit.",
          properties: {
            date: { type: "string" },
            title: { type: "string" },
            amount: { type: "string" },
            debit: { type: "string" },
            credit: { type: "string" },
            notes: { type: "string" },
            payment_method: { type: "string" }
          }
        }
      }.merge(extra)
    }
  end

  def read_statement_rows(file_path, args)
    root = Pathname.new(Rails.root).expand_path
    provided_path = Pathname.new(file_path)
    path = provided_path.absolute? ? provided_path.expand_path : root.join(provided_path).expand_path
    raise ArgumentError, "CSV file does not exist: #{path}" unless path.file?
    raise ArgumentError, "CSV file must be inside the project directory" unless path.ascend.any? { |ancestor| ancestor == root }

    CSV.read(
      path,
      headers: true,
      col_sep: args.fetch("col_sep", ","),
      encoding: args.fetch("encoding", "bom|utf-8"),
      liberal_parsing: true
    ).map(&:to_h)
  end

  def statement_attributes(row, mapping)
    title = value_at(row, mapping, "title") || value_at(row, mapping, "description")
    date = parse_date(value_at(row, mapping, "date"))
    amount = parse_amount(value_at(row, mapping, "amount"))

    if amount.nil?
      debit = parse_amount(value_at(row, mapping, "debit"))
      credit = parse_amount(value_at(row, mapping, "credit"))
      amount = credit || debit
      amount = -amount if credit.nil? && debit
    end

    raise ArgumentError, "Missing title in row: #{row.inspect}" if title.to_s.strip.empty?
    raise ArgumentError, "Missing date in row: #{row.inspect}" unless date
    raise ArgumentError, "Missing amount in row: #{row.inspect}" unless amount

    {
      title: title.to_s.strip,
      due_date: date.iso8601,
      amount: amount.abs,
      signed_amount: amount,
      transaction_type: amount.negative? ? "expense" : "income",
      payment_method: normalize_payment_method(value_at(row, mapping, "payment_method")),
      notes: value_at(row, mapping, "notes").to_s.strip.presence
    }
  end

  def value_at(row, mapping, key)
    column = mapping[key] || mapping[key.to_sym]
    return nil if column.to_s.empty?

    row[column]
  end

  def parse_date(value)
    text = value.to_s.strip
    return nil if text.empty?

    if text.match?(%r{\A\d{1,2}/\d{1,2}/\d{2,4}\z})
      day, month, year = text.split("/").map(&:to_i)
      year += 2000 if year < 100
      Date.new(year, month, day)
    else
      Date.parse(text)
    end
  rescue ArgumentError
    nil
  end

  def parse_amount(value)
    text = value.to_s.strip
    return nil if text.empty?

    negative = text.include?("-") || text.match?(/\A\(.*\)\z/)
    normalized = text.gsub(/[^\d,.-]/, "")

    if normalized.include?(",") && normalized.include?(".")
      normalized = normalized.rindex(",") > normalized.rindex(".") ? normalized.delete(".").tr(",", ".") : normalized.delete(",")
    elsif normalized.include?(",")
      normalized = normalized.tr(",", ".")
    end

    amount = BigDecimal(normalized.gsub(/[()]/, ""))
    negative ? -amount.abs : amount
  rescue ArgumentError
    nil
  end

  def normalize_payment_method(value)
    method = value.to_s.strip.downcase
    return "other" if method.empty?

    Transaction::PAYMENT_METHODS.key?(method) ? method : "other"
  end

  def idempotency_key(user_id, bank_account_id, attrs, row)
    source = [
      "statement_csv",
      user_id,
      bank_account_id,
      attrs[:due_date],
      attrs[:signed_amount].to_s("F"),
      normalize_description(attrs[:title]),
      row.to_json
    ].join("|")

    Digest::SHA256.hexdigest(source)
  end

  def totals_for(rows)
    {
      income_count: rows.count { |row| row[:transaction_type] == "income" },
      expense_count: rows.count { |row| row[:transaction_type] == "expense" },
      income_total: decimal_sum(rows.select { |row| row[:transaction_type] == "income" }),
      expense_total: decimal_sum(rows.select { |row| row[:transaction_type] == "expense" }),
      net_total: rows.sum { |row| row[:signed_amount] }.to_s("F")
    }
  end

  def decimal_sum(rows)
    rows.sum { |row| row[:amount] }.to_s("F")
  end

  def import_result(index, attrs, status, transaction_id, errors)
    {
      row_number: index,
      status: status,
      transaction_id: transaction_id,
      errors: errors,
      transaction: attrs
    }
  end

  def find_user(args)
    return User.find(args["user_id"]) if args["user_id"].present?
    return User.find_by!(email: args["user_email"]) if args["user_email"].present?

    users = User.order(:id).limit(2).to_a
    raise ArgumentError, "Provide user_id or user_email; multiple users exist" if users.length > 1
    raise ArgumentError, "No users found" if users.empty?

    users.first
  end

  def user_payload(user)
    {
      id: user.id,
      email: user.email,
      name: user.name
    }
  end

  def bank_account_payload(account)
    {
      id: account.id,
      name: account.name,
      bank_name: account.bank_name,
      account_type: account.account_type,
      active: account.active,
      balance: account.balance.to_s("F"),
      currency: account.currency
    }
  end

  def category_payload(category)
    {
      id: category.id,
      name: category.full_name,
      transaction_type: category.transaction_type,
      color: category.color
    }
  end

  def category_keyword_payload(keyword)
    {
      id: keyword.id,
      keyword: keyword.keyword,
      match_type: keyword.match_type,
      priority: keyword.priority,
      category: category_payload(keyword.category)
    }
  end

  def normalize_description(value)
    value.to_s.downcase.gsub(/[^\p{Alnum}\s]/, " ").squeeze(" ").strip
  end

  def keyword_candidate(normalized)
    normalized.split.first(4).join(" ")
  end

  def integer_arg(args, key, default)
    value = args[key] || args[key.to_sym]
    value.nil? ? default : value.to_i
  end

  def json_ready(value)
    case value
    when Hash
      value.transform_values { |item| json_ready(item) }
    when Array
      value.map { |item| json_ready(item) }
    when BigDecimal
      value.to_s("F")
    when Date, Time, DateTime
      value.iso8601
    else
      value
    end
  end

  def response(id, result)
    {
      jsonrpc: "2.0",
      id: id,
      result: result
    }
  end

  def error_response(id, code, message)
    {
      jsonrpc: "2.0",
      id: id,
      error: {
        code: code,
        message: message
      }
    }
  end
end
