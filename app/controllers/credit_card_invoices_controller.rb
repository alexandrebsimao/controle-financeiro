class CreditCardInvoicesController < ApplicationController
  require "csv"

  IMPORTABLE_FIELDS = %w[title amount credit_amount due_date purchased_at installments notes transaction_type].freeze

  before_action :set_credit_card
  before_action :set_invoice, only: [:show, :edit, :update, :pay, :preview_csv_import, :import_csv, :clear_csv_preview]

  def index
    @invoices = @credit_card.credit_card_invoices.order(reference_year: :desc, reference_month: :desc)
    @invoices = @invoices.page(params[:page]).per(12)
  end

  def show
    @expenses = @invoice.credit_card_expenses.includes(:credit_card_purchase).order(due_date: :asc)
    load_csv_preview_from_session!

    respond_to do |format|
      format.html
      format.csv do
        send_data expenses_csv(@invoice),
                  filename: "gastos-fatura-#{@invoice.id}-#{Date.current}.csv",
                  type: "text/csv; charset=utf-8"
      end
    end
  end

  def edit
  end

  def update
    if @invoice.update(invoice_params)
      redirect_to @invoice, notice: "Fatura atualizada!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def pay
    result = InvoicePaymentService.new(@invoice, invoice_payment_params[:bank_account_id]).call

    if result.success?
      redirect_to @credit_card, notice: "Fatura paga com sucesso!"
    else
      redirect_to @credit_card, alert: result.message
    end
  end

  def preview_csv_import
    csv_file = params[:csv_file]
    raw_content =
      if csv_file.present?
        csv_file.read
      elsif params[:raw_csv_content].present?
        Base64.decode64(params[:raw_csv_content])
      end

    if raw_content.blank?
      clear_csv_preview_session!
      @expenses = @invoice.credit_card_expenses.includes(:credit_card_purchase).order(due_date: :asc)
      load_csv_preview_from_session!
      flash.now[:alert] = "Selecione um arquivo CSV para importar."
      render :show, status: :unprocessable_entity
      return
    end

    parsed = parse_csv_content(raw_content)
    csv_headers = parsed[:headers]

    if csv_headers.blank? || parsed[:rows].blank?
      clear_csv_preview_session!
      @expenses = @invoice.credit_card_expenses.includes(:credit_card_purchase).order(due_date: :asc)
      load_csv_preview_from_session!
      flash.now[:alert] = "O arquivo CSV está vazio ou em formato não reconhecido."
      render :show, status: :unprocessable_entity
      return
    end

    submitted_mapping = sanitized_field_mapping(params[:field_mapping] || {})
    auto_mapping = default_field_mapping(csv_headers)

    # Use submitted mapping only if it matches headers in the current CSV
    valid_submitted = submitted_mapping.select { |_k, v| v.present? && csv_headers.include?(v) }
    field_mapping = auto_mapping.merge(valid_submitted)

    preview_rows = build_preview_rows(parsed[:rows], field_mapping)

    if preview_rows.empty?
      clear_csv_preview_session!
      @expenses = @invoice.credit_card_expenses.includes(:credit_card_purchase).order(due_date: :asc)
      load_csv_preview_from_session!
      flash.now[:alert] = "Nenhuma compra válida pôde ser extraída do arquivo CSV."
      render :show, status: :unprocessable_entity
      return
    end

    store_csv_preview_in_session!(csv_headers, field_mapping, preview_rows)

    @csv_headers = csv_headers
    @field_mapping = field_mapping
    @preview_rows = preview_rows
    @raw_csv_content = raw_content.bytesize < 500_000 ? Base64.strict_encode64(raw_content) : nil
    @expenses = @invoice.credit_card_expenses.includes(:credit_card_purchase).order(due_date: :asc)

    purchases_count = @preview_rows.count { |r| !r[:is_refund] && !r[:is_invoice_payment] }
    refunds_count = @preview_rows.count { |r| r[:is_refund] }
    payments_count = @preview_rows.count { |r| r[:is_invoice_payment] }
    notice_parts = []
    notice_parts << "#{purchases_count} compra(s)" if purchases_count > 0
    notice_parts << "#{refunds_count} reembolso(s)/estorno(s)" if refunds_count > 0
    notice_parts << "#{payments_count} pagamento(s) de fatura" if payments_count > 0
    notice_msg = notice_parts.present? ? notice_parts.join(", ") : "#{@preview_rows.size} item(ns)"
    flash.now[:notice] = "Prévia gerada com sucesso! #{notice_msg} encontrado(s)."
    render :show
  rescue CSV::MalformedCSVError => e
    clear_csv_preview_session!
    @expenses = @invoice.credit_card_expenses.includes(:credit_card_purchase).order(due_date: :asc)
    load_csv_preview_from_session!
    flash.now[:alert] = "CSV inválido ou corrompido: #{e.message}"
    render :show, status: :unprocessable_entity
  rescue StandardError => e
    clear_csv_preview_session!
    @expenses = @invoice.credit_card_expenses.includes(:credit_card_purchase).order(due_date: :asc)
    load_csv_preview_from_session!
    flash.now[:alert] = "Erro ao processar CSV: #{e.message}"
    render :show, status: :unprocessable_entity
  end

  def clear_csv_preview
    clear_csv_preview_session!
    redirect_to credit_card_invoice_path(@credit_card, @invoice), notice: "Prévia de importação cancelada."
  end

  def import_csv
    imported_count = 0
    selected_ids = Array(params[:selected_rows]).map(&:to_i)
    preview_rows = JSON.parse(params[:preview_rows_json].to_s)

    rows_to_import = preview_rows.select do |row|
      row_id = (row["row_id"] || row[:row_id]).to_i
      selected_ids.include?(row_id)
    end

    if rows_to_import.empty?
      redirect_to credit_card_invoice_path(@credit_card, @invoice), alert: "Selecione ao menos uma linha para importar."
      return
    end

    ActiveRecord::Base.transaction do
      rows_to_import.each do |row|
        row = row.with_indifferent_access
        amount = parse_decimal(row[:amount])
        next if amount == 0

        is_refund = row[:is_refund] == true || row[:is_refund] == "true" || amount < 0
        final_amount = is_refund ? -amount.abs : amount.abs

        purchased_at = parse_date(row[:purchased_at]) || @invoice.closing_date || Date.current
        due_date = parse_date(row[:due_date]) || @invoice.due_date
        installments = row[:installments].to_i
        installments = 1 if installments <= 0

        default_title = is_refund ? "Reembolso CSV ##{row[:row_id]}" : "Importado CSV ##{row[:row_id]}"
        purchase = @credit_card.credit_card_purchases.create!(
          title: row[:title].presence || default_title,
          total_amount: final_amount * installments,
          purchased_at: purchased_at,
          installments: installments,
          notes: row[:notes].presence
        )

        first_expense = purchase.credit_card_expenses.order(:installment_number).first
        if first_expense
          first_expense.update!(
            invoice: @invoice,
            due_date: due_date,
            amount: final_amount
          )
        end

        imported_count += 1
      end
    end

    @invoice.recalculate_total!

    clear_csv_preview_session!
    redirect_to credit_card_invoice_path(@credit_card, @invoice), notice: "#{imported_count} item(ns) importado(s) com sucesso para esta fatura."
  rescue JSON::ParserError
    redirect_to credit_card_invoice_path(@credit_card, @invoice), alert: "Dados de prévia inválidos. Refaça a prévia da importação."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to credit_card_invoice_path(@credit_card, @invoice), alert: "Erro ao importar CSV: #{e.record.errors.full_messages.to_sentence}"
  rescue StandardError => e
    redirect_to credit_card_invoice_path(@credit_card, @invoice), alert: "Erro inesperado ao importar CSV: #{e.message}"
  end

  private

  def expenses_csv(invoice)
    expenses = invoice.credit_card_expenses.includes(credit_card_purchase: :category).order(due_date: :asc)
    CSV.generate(headers: true) do |csv|
      csv << ["Cartao", "Compra", "Categoria", "Parcela", "Valor da parcela", "Vencimento da parcela", "Referencia da fatura", "Vencimento da fatura", "Fatura paga", "Data pagamento fatura", "Observacoes da compra"]

      expenses.each do |expense|
        purchase = expense.credit_card_purchase

        csv << [
          invoice.credit_card&.name,
          purchase&.title,
          purchase&.category&.name,
          expense.installment_number,
          expense.amount,
          expense.due_date,
          "#{invoice.reference_month}/#{invoice.reference_year}",
          invoice.due_date,
          invoice.paid? ? "Sim" : "Nao",
          invoice.paid_at,
          purchase&.notes
        ]
      end
    end
  end

  def set_credit_card
    @credit_card = current_user.credit_cards.find(params[:credit_card_id])
  end

  def set_invoice
    @invoice = @credit_card.credit_card_invoices.find(params[:id])
  end

  def invoice_params
    params.require(:credit_card_invoice).permit(:notes)
  end

  def invoice_payment_params
    params.require(:credit_card_invoice).permit(:bank_account_id)
  end

  def parse_csv_content(raw)
    return { headers: [], rows: [] } if raw.blank?

    content =
      if raw.dup.force_encoding("UTF-8").valid_encoding?
        raw.dup.force_encoding("UTF-8")
      else
        raw.encode("UTF-8", "ISO-8859-1", invalid: :replace, undef: :replace, replace: "")
      end

    content = content.sub(/\A\xEF\xBB\xBF/, "")
    content = content.sub(/\A\uFEFF/, "")

    col_sep = detect_separator(content)
    lines = content.lines
    header_index = lines.find_index { |line| line.include?(col_sep) && line.strip.present? } || 0
    clean_content = lines[header_index..-1].join

    parsed = CSV.parse(
      clean_content,
      headers: true,
      col_sep: col_sep,
      liberal_parsing: true,
      skip_blanks: true
    )

    clean_headers = (parsed.headers || []).compact.map(&:strip).reject(&:empty?)
    rows = parsed.map do |row|
      row.to_h.transform_keys { |k| k.to_s.strip }
    end

    { headers: clean_headers, rows: rows }
  end

  def detect_separator(content)
    candidate_line = content.to_s.lines.map(&:strip).reject(&:empty?).find { |l| l.include?(";") || l.include?(",") || l.include?("\t") }
    return "," if candidate_line.blank?

    counts = {
      ";" => candidate_line.count(";"),
      "," => candidate_line.count(","),
      "\t" => candidate_line.count("\t")
    }

    counts.max_by { |_sep, count| count }&.first || ","
  end

  def default_field_mapping(headers)
    return {} if headers.blank?

    headers_by_norm = {}
    headers.each { |h| headers_by_norm[normalize_header(h)] ||= h }

    find_header = lambda do |*keys|
      keys.each do |k|
        matched = headers_by_norm[k]
        return matched if matched.present?
      end
      keys.each do |k|
        matched = headers.find { |h| normalize_header(h).include?(k) }
        return matched if matched.present?
      end
      nil
    end

    {
      "title" => find_header.call(
        "descricao", "descricao_compra", "compra", "title", "titulo",
        "estabelecimento", "historico", "historico_lancamento",
        "historico_de_lancamento", "lancamento", "detalhes", "detalhe",
        "transacao", "item", "merchant", "nome"
      ),
      "amount" => find_header.call(
        "valor", "valor_parcela", "amount", "valor_r", "valor_em_r",
        "valor_brl", "quantia", "total", "debito", "debit", "valor_debito"
      ),
      "credit_amount" => find_header.call(
        "credito", "valor_credito", "creditos", "valor_de_credito", "credit", "credit_amount", "reembolso", "estorno"
      ),
      "transaction_type" => find_header.call(
        "tipo", "tipo_de_transacao", "tipo_transacao", "tipo_lancamento",
        "natureza", "operacao", "transacao", "d_c", "debito_credito", "credito_debito", "sinal"
      ),
      "due_date" => find_header.call(
        "vencimento", "data_vencimento", "data_de_vencimento", "due_date", "venc"
      ),
      "purchased_at" => find_header.call(
        "data_compra", "data_da_compra", "data_transacao", "data", "date",
        "purchased_at", "dt_compra", "data_lancamento", "dt_lancamento"
      ),
      "installments" => find_header.call(
        "parcelas", "parcela", "installments", "numero_de_parcelas", "qtd_parcelas"
      ),
      "notes" => find_header.call(
        "observacoes", "observacao", "notes", "categoria", "category"
      )
    }.compact
  end

  def sanitized_field_mapping(mapping)
    raw_mapping =
      if mapping.respond_to?(:permit)
        mapping.permit(*IMPORTABLE_FIELDS).to_h
      else
        mapping.to_h
      end

    raw_mapping.slice(*IMPORTABLE_FIELDS).transform_values(&:to_s)
  end

  def build_preview_rows(rows, mapping)
    all_raw_amounts = rows.map { |r| extract_value(r, mapping["amount"]).to_s.strip }
    negative_count = all_raw_amounts.count { |a| a.include?("-") || a.include?("–") || a.include?("−") || a.match?(/\A\(.*\)\z/) }
    inverted_convention = negative_count > 0 && (negative_count.to_f / [rows.size, 1].max) > 0.7

    rows.each_with_index.filter_map do |row, idx|
      title = extract_value(row, mapping["title"]).to_s.strip
      raw_amount = extract_value(row, mapping["amount"]).to_s.strip
      raw_credit = extract_value(row, mapping["credit_amount"]).to_s.strip
      type_val = extract_value(row, mapping["transaction_type"]).to_s.strip
      due_date_raw = extract_value(row, mapping["due_date"])
      purchased_at_raw = extract_value(row, mapping["purchased_at"])
      installments_raw = extract_value(row, mapping["installments"])
      notes = extract_value(row, mapping["notes"]).to_s.strip

      amount = parse_decimal(raw_amount)
      credit_amount = parse_decimal(raw_credit)

      # If separate credit column has a value and debit/amount is empty or 0:
      if credit_amount > 0 && (amount == 0 || raw_amount.blank?)
        amount = -credit_amount
        raw_amount = "-#{raw_credit}"
      elsif amount == 0 || raw_amount.blank?
        # Auto-detect if any unmapped column in row has a credit header
        credit_header = row.keys.find { |k| normalize_header(k) =~ /\A(credito|valor_credito|credit|valor_de_credito|reembolso)\z/ }
        if credit_header
          unmapped_credit = parse_decimal(row[credit_header])
          if unmapped_credit > 0
            amount = -unmapped_credit
            raw_amount = "-#{row[credit_header]}"
          end
        end
      end

      purchased_at = parse_date(purchased_at_raw) || parse_date(due_date_raw)
      due_date = parse_date(due_date_raw) || @invoice.due_date

      # Skip empty or summary rows
      next if title.blank? && amount == 0

      is_invoice_payment = detect_invoice_payment(title, row)
      is_refund = detect_refund(title, raw_amount, notes, inverted_convention, row, type_val)

      final_amount =
        if is_refund || is_invoice_payment
          -amount.abs
        elsif inverted_convention && amount < 0
          amount.abs
        else
          amount.abs
        end

      # Check if installments is specified like "1/3" or "Parcela 2 de 5"
      installments = installments_raw.to_s.split(%r{[/de\s]+}).last.to_i
      if installments <= 0 && title =~ %r{(\d+)[/\\](\d+)}
        installments = $2.to_i
      end
      installments = 1 if installments <= 0

      default_title =
        if is_invoice_payment
          "Pagamento de Fatura ##{idx + 1}"
        elsif is_refund
          "Reembolso ##{idx + 1}"
        else
          "Item ##{idx + 1}"
        end

      {
        row_id: idx + 1,
        title: title.presence || default_title,
        amount: sprintf("%.2f", final_amount),
        is_refund: is_refund,
        is_invoice_payment: is_invoice_payment,
        due_date: due_date&.strftime("%Y-%m-%d"),
        purchased_at: purchased_at&.strftime("%Y-%m-%d"),
        installments: installments.to_s,
        notes: notes.presence
      }.with_indifferent_access
    end
  end

  def detect_refund(title, raw_amount, notes, inverted_convention, row = {}, type_val = nil)
    return false if detect_invoice_payment(title, row)

    # 1. Check explicit transaction_type / operation / natureza column or parameter
    type_str = I18n.transliterate("#{type_val} #{extract_row_type(row)}").downcase.strip
    if type_str =~ /\b(credito|credit|cr|estorno|reembolso|devolucao|refund|entrada|receita)\b|\Ac\z/
      return true
    end

    # 2. Check title, notes, and entire row text for refund keywords
    all_row_text = I18n.transliterate("#{title} #{notes} #{row.values.compact.join(' ')}").downcase
    has_refund_keyword = !!(all_row_text =~ /\b(estorno|estornos|reembolso|reembolsos|devolucao|devolucoes|devolvido|devolvida|chargeback|credito|creditos|cashback|cancelamento|cancelad[oa]|reversao|revertid[oa]|refund|reversal|abatimento)\b|\b(est|dev|reemb)\.|\b(est|reemb)\s+/)

    # 3. Check raw amount and parsed amount for negative sign / credit flags
    raw_str = raw_amount.to_s.strip.gsub(/[\u2012\u2013\u2014\u2015\u2212\uFE63\uFF0D]/, "-")
    raw_is_negative = !!(raw_str.include?("-") || (raw_str.include?("(") && raw_str.include?(")")) || (raw_str =~ /\b(CR|C)\b/i) || (raw_str =~ /\d+\s*(?:CR|C)\z/i))

    if has_refund_keyword
      true
    elsif inverted_convention
      # In inverted convention, debits are negative, so non-negative amounts with non-empty string are credits/refunds
      !raw_is_negative && raw_str.present?
    else
      raw_is_negative
    end
  end

  def extract_row_type(row)
    return "" if row.blank?

    type_key = row.keys.find { |k| normalize_header(k) =~ /\A(tipo|tipo_de_transacao|tipo_transacao|tipo_lancamento|natureza|operacao|transacao|d_c|debito_credito|credito_debito|sinal)\z/ }
    type_key ? row[type_key].to_s : ""
  end

  def detect_invoice_payment(title, row = {})
    text = I18n.transliterate("#{title} #{row.values.compact.join(' ')}").downcase
    !!(text =~ /\b(pagamento\s+recebido|pagamento\s+de\s+fatura|pagamento\s+efetuado|pagamento\s+fatura|pgto\s+fatura|pagto\s+fatura|pagamento\s+em\s+conta|pgto\s+recebido)\b/)
  end

  def extract_value(row, header)
    return nil if header.blank?

    row[header]
  end

  def normalize_header(value)
    I18n.transliterate(value.to_s)
      .downcase
      .gsub(/[^a-z0-9]+/, "_")
      .gsub(/\A_+|_+\z/, "")
  end

  def parse_decimal(value)
    return BigDecimal(0) if value.blank?

    raw = value.to_s.strip
    return BigDecimal(0) if raw.blank?

    # Normalize Unicode minus signs: –, —, −, etc.
    raw = raw.gsub(/[\u2012\u2013\u2014\u2015\u2212\uFE63\uFF0D]/, "-")

    # Check for negative indicators
    has_trailing_minus = (raw =~ /\d+\s*-\z/)
    has_leading_minus = raw.include?("-")
    has_parentheses = raw.include?("(") && raw.include?(")")
    has_credit_flag = (raw =~ /\b(CR|C)\b/i || raw =~ /\d+\s*(?:CR|C)\z/i)

    is_negative = !!(has_leading_minus || has_trailing_minus || has_parentheses || has_credit_flag)

    # Clean out currency, spaces, parentheses, CR/C/D markers
    cleaned = raw.gsub(/[R$BRL\s\u00A0]/i, "")
                 .gsub(/[\(\)]/, "")
                 .gsub(/(?:CR|C|D|DB)\z/i, "")
                 .gsub(/[^\d,.-]/, "")
                 .gsub(/-/, "")
    return BigDecimal(0) if cleaned.blank?

    if cleaned.include?(".") && cleaned.include?(",")
      decimal_separator = cleaned.rindex(".") > cleaned.rindex(",") ? "." : ","
      thousands_separator = decimal_separator == "." ? "," : "."
      normalized = cleaned.gsub(thousands_separator, "").tr(decimal_separator, ".")
    elsif cleaned.include?(",")
      normalized = cleaned.tr(",", ".")
    else
      normalized = cleaned
    end

    amount = BigDecimal(normalized.presence || "0").abs
    is_negative ? -amount : amount
  rescue ArgumentError, TypeError
    BigDecimal(0)
  end

  def parse_date(value)
    text = value.to_s.strip
    return nil if text.blank?

    if text =~ %r{\A(\d{1,2})/(\d{1,2})/(\d{2,4})\z}
      day, month, year = text.split("/").map(&:to_i)
      year += 2000 if year < 100
      Date.new(year, month, day)
    elsif text =~ %r{\A(\d{1,2})-(\d{1,2})-(\d{2,4})\z}
      day, month, year = text.split("-").map(&:to_i)
      year += 2000 if year < 100
      Date.new(year, month, day)
    elsif text =~ %r{\A(\d{4})-(\d{1,2})-(\d{1,2})\z}
      year, month, day = text.split("-").map(&:to_i)
      Date.new(year, month, day)
    else
      Date.parse(text)
    end
  rescue ArgumentError, Date::Error
    nil
  end

  def load_csv_preview_from_session!
    preview = Rails.cache.read(csv_preview_cache_key) rescue nil
    @csv_headers = preview&.dig("csv_headers") || []
    @field_mapping = preview&.dig("field_mapping") || default_field_mapping(@csv_headers)
    raw_rows = preview&.dig("preview_rows") || []
    @preview_rows = raw_rows.map(&:with_indifferent_access)
  end

  def store_csv_preview_in_session!(headers, field_mapping, preview_rows)
    Rails.cache.write(csv_preview_cache_key, {
      "csv_headers" => headers,
      "field_mapping" => field_mapping,
      "preview_rows" => preview_rows
    }, expires_in: 30.minutes)
  rescue StandardError => e
    Rails.logger.warn("Falha ao salvar prévia no cache: #{e.message}")
  end

  def clear_csv_preview_session!
    Rails.cache.delete(csv_preview_cache_key)
  rescue StandardError => e
    Rails.logger.warn("Falha ao remover prévia do cache: #{e.message}")
  end

  def csv_preview_cache_key
    "credit_card_invoice_csv_preview:user:#{current_user.id}:invoice:#{@invoice.id}"
  end
end
