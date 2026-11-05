# frozen_string_literal: true

class FinancialAnalysisService
  def initialize(user, provider: nil, model: nil)
    @user = user
    @provider = provider.presence || @user.preferred_ai_provider
    @model = model
  end

  def call
    metrics = collect_financial_data
    period_label = Date.today.strftime("%m/%Y")
    
    system_prompt = build_system_prompt
    user_prompt = build_user_prompt(metrics)

    ai_result = AiService.chat(
      prompt: user_prompt,
      system_prompt: system_prompt,
      provider: @provider,
      model: @model,
      temperature: 0.3,
      user: @user
    )

    content = ai_result[:content]
    model_used = ai_result[:model_used]
    provider_used = ai_result[:provider]
    summary = extract_summary(content)

    insight_attributes = {
      title: "Análise e Oportunidades de Economia (#{period_label})",
      period: period_label,
      summary: summary,
      content: content,
      raw_metrics: metrics,
      model_used: model_used,
      status: "completed"
    }
    insight_attributes[:ai_provider] = provider_used if FinancialInsight.column_names.include?("ai_provider")

    @user.financial_insights.create!(insight_attributes)
  end

  private

  def collect_financial_data
    today = Date.today
    cur_start = today.beginning_of_month
    cur_end = today.end_of_month
    cur_year = today.year
    cur_month = today.month

    # Cartões de crédito estritamente ATIVOS e suas faturas
    active_cards = @user.active_credit_cards
    active_invoices = @user.active_credit_card_invoices

    # Faturas do mês atual dos cartões ativos (competência/referência do mês atual ou com vencimento no mês)
    cur_month_invoices = active_invoices
      .where(reference_year: cur_year, reference_month: cur_month)
      .or(active_invoices.where(due_date: cur_start..cur_end))
      .distinct

    paid_invoices_amount = cur_month_invoices.where(paid: true).sum(:total_amount).to_d
    pending_invoices_amount = cur_month_invoices.where(paid: false).sum(:total_amount).to_d

    # Movimentações de conta corrente (PIX, Boleto, Débito, etc.), excluindo pagamento de fatura para não duplicar
    non_cc_expenses = @user.transactions.ignore_transfers.expense
      .where("payment_method IS NULL OR payment_method != ?", "credit_card_bill")

    # 1. Mês Atual: Realizado (Pago)
    realized_income = @user.transactions.ignore_transfers.income.paid.for_period(cur_start, cur_end).sum(:amount).to_d

    realized_direct = non_cc_expenses.paid.for_period(cur_start, cur_end)
    realized_explicit_inv = @user.transactions.ignore_transfers.investment.paid.for_period(cur_start, cur_end).sum(:amount).to_d
    realized_legacy_inv = realized_direct.joins(:category).where("LOWER(categories.name) LIKE ?", "%investimento%").sum(:amount).to_d
    realized_investments = realized_explicit_inv + realized_legacy_inv

    realized_direct_operational = realized_direct.left_joins(:category)
      .where("categories.name IS NULL OR LOWER(categories.name) NOT LIKE ?", "%investimento%")
      .sum(:amount).to_d

    # Despesas operacionais realizadas = contas pagas + faturas de cartão pagas
    realized_operational_expenses = realized_direct_operational + paid_invoices_amount

    # 2. Mês Atual: Previsto / Pendente (A Receber / A Pagar)
    pending_income = @user.transactions.ignore_transfers.income.unpaid.for_period(cur_start, cur_end).sum(:amount).to_d

    pending_direct = non_cc_expenses.unpaid.for_period(cur_start, cur_end)
    pending_explicit_inv = @user.transactions.ignore_transfers.investment.unpaid.for_period(cur_start, cur_end).sum(:amount).to_d
    pending_legacy_inv = pending_direct.joins(:category).where("LOWER(categories.name) LIKE ?", "%investimento%").sum(:amount).to_d
    pending_investments = pending_explicit_inv + pending_legacy_inv

    pending_direct_operational = pending_direct.left_joins(:category)
      .where("categories.name IS NULL OR LOWER(categories.name) NOT LIKE ?", "%investimento%")
      .sum(:amount).to_d

    # Despesas operacionais pendentes = contas a pagar + faturas pendentes do cartão
    pending_operational_expenses = pending_direct_operational + pending_invoices_amount

    # Totais consolidados com Previsão do Mês
    total_projected_income = realized_income + pending_income
    total_projected_operational_expenses = realized_operational_expenses + pending_operational_expenses
    total_projected_investments = realized_investments + pending_investments
    projected_operational_balance = total_projected_income - total_projected_operational_expenses
    projected_final_cash_flow = projected_operational_balance - total_projected_investments

    # 3. Análise do Descasamento Temporal de Caixa (Dias 1 a 19 vs Dia 20 em diante)
    day_19_limit = Date.new(today.year, today.month, [19, today.end_of_month.day].min)
    day_20_start = Date.new(today.year, today.month, [20, today.end_of_month.day].min)

    # Início do mês (Dias 1 a 19): gastos concentrados antes do salário
    early_income = @user.transactions.ignore_transfers.income.for_period(cur_start, day_19_limit).sum(:amount).to_d
    early_direct_expenses = non_cc_expenses.for_period(cur_start, day_19_limit)
      .left_joins(:category)
      .where("categories.name IS NULL OR LOWER(categories.name) NOT LIKE ?", "%investimento%")
      .sum(:amount).to_d
    early_invoices = cur_month_invoices.where(due_date: cur_start..day_19_limit).sum(:total_amount).to_d
    total_early_commitments = early_direct_expenses + early_invoices
    early_cash_gap = total_early_commitments - early_income

    # Final do mês (Dia 20 em diante): entrada da renda principal
    late_income = @user.transactions.ignore_transfers.income.for_period(day_20_start, cur_end).sum(:amount).to_d
    late_direct_expenses = non_cc_expenses.for_period(day_20_start, cur_end)
      .left_joins(:category)
      .where("categories.name IS NULL OR LOWER(categories.name) NOT LIKE ?", "%investimento%")
      .sum(:amount).to_d
    late_invoices = cur_month_invoices.where(due_date: day_20_start..cur_end).sum(:total_amount).to_d
    total_late_commitments = late_direct_expenses + late_invoices

    # Saldo bancário atual disponível
    total_bank_balance = @user.bank_accounts.active.sum(:balance).to_f.round(2)

    # Se hoje for antes do dia 20, calcular quanto ainda vai vencer até o dia 20
    pending_bills_until_20 = 0.to_d
    if today.day < 20
      p_exp = non_cc_expenses.unpaid.for_period(today, day_19_limit)
        .left_joins(:category)
        .where("categories.name IS NULL OR LOWER(categories.name) NOT LIKE ?", "%investimento%")
        .sum(:amount).to_d
      p_inv = cur_month_invoices.where(paid: false, due_date: today..day_19_limit).sum(:total_amount).to_d
      pending_bills_until_20 = p_exp + p_inv
    end

    # Faturas de Cartão e Contas que vencem antes do dia 20 (candidatas a troca de data)
    early_bills_list = non_cc_expenses.for_period(cur_start, day_19_limit)
      .left_joins(:category)
      .where("categories.name IS NULL OR LOWER(categories.name) NOT LIKE ?", "%investimento%")
      .order(amount: :desc)
      .limit(6)
      .map { |t| { title: t.title, due_date: t.due_date.to_s, amount: t.amount.to_f.round(2) } }

    cur_month_invoices.where(due_date: cur_start..day_19_limit).each do |inv|
      early_bills_list << {
        title: "Fatura #{inv.credit_card.name} (#{inv.reference_label})",
        due_date: inv.due_date.to_s,
        amount: inv.total_amount.to_f.round(2)
      }
    end

    # 4. Despesas Operacionais por Categoria (Consolidadas: Contas Correntes + Fatura do Cartão)
    category_totals = Hash.new(0.to_d)

    # Categorias de transações diretas (excluindo faturas e investimentos)
    non_cc_expenses.for_period(cur_start, cur_end).includes(:category).each do |t|
      cat_name = t.category&.name || "Sem Categoria"
      next if cat_name.downcase.include?("investimento")
      category_totals[cat_name] += t.amount.to_d
    end

    # Categorias das compras na fatura do mês atual dos cartões ativos
    cur_month_invoices.includes(credit_card_expenses: { credit_card_purchase: :category }).each do |inv|
      inv_expenses_sum = 0.to_d
      inv.credit_card_expenses.each do |exp|
        cat_name = exp.credit_card_purchase&.category&.name || "Cartão de Crédito - Geral"
        next if cat_name.downcase.include?("investimento")
        category_totals[cat_name] += exp.amount.to_d
        inv_expenses_sum += exp.amount.to_d
      end
      diff = inv.total_amount.to_d - inv_expenses_sum
      if diff.positive?
        category_totals["Cartão de Crédito - Outros"] += diff
      end
    end

    categories_breakdown = category_totals.sort_by { |_, amt| -amt }.map do |name, amt|
      percent = total_projected_operational_expenses.positive? ? ((amt / total_projected_operational_expenses) * 100).round(1) : 0.0
      { category: name, amount: amt.to_f.round(2), percentage: percent }
    end

    # 5. Projeção dos Próximos 3 Meses
    future_forecast = []
    1.upto(3) do |i|
      m_date = i.months.from_now.to_date
      m_start = m_date.beginning_of_month
      m_end = m_date.end_of_month
      f_income = @user.transactions.ignore_transfers.income.for_period(m_start, m_end).sum(:amount).to_d
      f_exp = non_cc_expenses.for_period(m_start, m_end)
        .left_joins(:category)
        .where("categories.name IS NULL OR LOWER(categories.name) NOT LIKE ?", "%investimento%")
        .sum(:amount).to_d
      f_inv = active_invoices.where(reference_year: m_date.year, reference_month: m_date.month, paid: false).sum(:total_amount).to_d
      total_f_exp = f_exp + f_inv

      future_forecast << {
        month: m_start.strftime("%m/%Y"),
        expected_income: f_income.to_f.round(2),
        expected_operational_expenses: total_f_exp.to_f.round(2),
        projected_net: (f_income - total_f_exp).to_f.round(2)
      }
    end

    # Histórico dos 3 meses anteriores
    history = []
    3.downto(1) do |i|
      m_date = i.months.ago.to_date
      m_start = m_date.beginning_of_month
      m_end = m_date.end_of_month
      inc = @user.transactions.ignore_transfers.income.paid.for_period(m_start, m_end).sum(:amount).to_d
      tot_direct = non_cc_expenses.paid.for_period(m_start, m_end).sum(:amount).to_d
      inv_exp = non_cc_expenses.paid
        .for_period(m_start, m_end)
        .joins(:category)
        .where("LOWER(categories.name) LIKE ?", "%investimento%")
        .sum(:amount).to_d
      op_direct = tot_direct - inv_exp
      past_inv = active_invoices.where(reference_year: m_date.year, reference_month: m_date.month, paid: true).sum(:total_amount).to_d
      total_past_op = op_direct + past_inv

      history << {
        month: m_start.strftime("%m/%Y"),
        income: inc.to_f.round(2),
        operational_expenses: total_past_op.to_f.round(2),
        investments: inv_exp.to_f.round(2),
        net_operational: (inc - total_past_op).to_f.round(2)
      }
    end

    # 6. Detalhamento Aprofundado das Faturas de Cartão de Crédito (ESTRITAMENTE ATIVOS)
    detailed_credit_cards = active_cards.includes(:bank_account).map do |card|
      cur_inv = card.invoice_for(today.year, today.month) || card.current_invoice
      prev_m = today.prev_month
      prev_inv = card.invoice_for(prev_m.year, prev_m.month)

      target_invoices = [cur_inv, prev_inv].compact.uniq
      unpaid_with_debt = card.credit_card_invoices.unpaid.where("total_amount > 0").order(due_date: :asc).to_a
      target_invoices = (target_invoices + unpaid_with_debt).uniq.first(3)

      invoices_data = target_invoices.map do |inv|
        expenses = inv.credit_card_expenses.includes(credit_card_purchase: :category)

        # Gastos por categoria dentro da fatura
        inv_categories = Hash.new(0.to_d)
        installment_items = []
        regular_items = []

        expenses.each do |exp|
          purchase = exp.credit_card_purchase
          cat_name = purchase&.category&.name || "Sem Categoria"
          inv_categories[cat_name] += exp.amount.to_d

          item_info = {
            title: purchase&.title || "Compra",
            amount: exp.amount.to_f.round(2),
            category: cat_name,
            installment: "#{exp.installment_number}/#{purchase&.installments || 1}",
            total_purchase_amount: purchase&.total_amount.to_f.round(2),
            purchased_at: purchase&.purchased_at&.to_s
          }

          if purchase && purchase.installments > 1
            remaining = [purchase.installments - exp.installment_number, 0].max
            item_info[:remaining_installments] = remaining
            item_info[:future_remaining_debt] = (remaining * exp.amount).to_f.round(2)
            installment_items << item_info
          else
            regular_items << item_info
          end
        end

        sorted_inv_categories = inv_categories.sort_by { |_, v| -v }.map do |cat, amt|
          pct = inv.total_amount.positive? ? ((amt / inv.total_amount) * 100).round(1) : 0.0
          { category: cat, amount: amt.to_f.round(2), percentage: pct }
        end

        top_invoice_expenses = expenses.sort_by { |e| -e.amount.to_d }.first(8).map do |e|
          p = e.credit_card_purchase
          {
            title: p&.title || "Compra",
            amount: e.amount.to_f.round(2),
            category: p&.category&.name || "Geral",
            installment: "#{e.installment_number}/#{p&.installments || 1}"
          }
        end

        limit_usage = (card.credit_limit.to_d.positive?) ? ((inv.total_amount / card.credit_limit) * 100).round(1) : 0.0

        {
          reference_label: inv.reference_label,
          month: inv.reference_month,
          year: inv.reference_year,
          due_date: inv.due_date.to_s,
          closing_date: inv.closing_date.to_s,
          paid: inv.paid?,
          total_amount: inv.total_amount.to_f.round(2),
          limit_utilization_percent: limit_usage,
          categories_breakdown: sorted_inv_categories,
          top_expenses: top_invoice_expenses,
          total_active_installments_count: installment_items.size,
          active_installments: installment_items.first(12),
          total_installment_amount_this_invoice: installment_items.sum { |i| i[:amount] }.round(2),
          total_future_debt_from_installments: installment_items.sum { |i| i[:future_remaining_debt] }.round(2)
        }
      end

      {
        card_name: card.name,
        brand: card.brand,
        credit_limit: card.credit_limit.to_f.round(2),
        closing_day: card.closing_day,
        due_day: card.due_day,
        invoices: invoices_data
      }
    end

    {
      user_name: @user.name,
      currency: "BRL (R$)",
      current_date: today.to_s,
      total_bank_balance: total_bank_balance,
      cash_flow_timing_analysis: {
        note: "O usuário tem despesas concentradas no início do mês (dias 1 a 19), mas recebe renda principalmente no dia 20.",
        early_month_commitments_until_day_19: total_early_commitments.to_f.round(2),
        early_month_income_until_day_19: early_income.to_f.round(2),
        early_cash_deficit: early_cash_gap.to_f.round(2),
        late_month_income_from_day_20: late_income.to_f.round(2),
        late_month_commitments_from_day_20: total_late_commitments.to_f.round(2),
        current_bank_balance: total_bank_balance,
        pending_bills_before_day_20: pending_bills_until_20.to_f.round(2),
        recommended_working_capital_buffer: [early_cash_gap, 0].max.to_f.round(2),
        bills_due_before_day_20: early_bills_list
      },
      current_month_forecast: {
        period: today.strftime("%m/%Y"),
        total_projected_income: total_projected_income.to_f.round(2),
        realized_income_so_far: realized_income.to_f.round(2),
        pending_income_expected: pending_income.to_f.round(2),
        total_projected_operational_expenses: total_projected_operational_expenses.to_f.round(2),
        realized_operational_expenses: realized_operational_expenses.to_f.round(2),
        pending_operational_expenses: pending_operational_expenses.to_f.round(2),
        paid_card_invoices: paid_invoices_amount.to_f.round(2),
        pending_card_invoices: pending_invoices_amount.to_f.round(2),
        investments: total_projected_investments.to_f.round(2),
        projected_operational_balance: projected_operational_balance.to_f.round(2),
        projected_final_cash_flow: projected_final_cash_flow.to_f.round(2),
        categories: categories_breakdown
      },
      future_months_forecast: future_forecast,
      past_months: history,
      active_recurrences: @user.recurrences.active.includes(:category).map { |r| { title: r.title, amount: r.amount.to_f.round(2), frequency: r.frequency, type: r.transaction_type, category: r.category&.name || "Geral" } },
      credit_cards_and_invoices_detailed: detailed_credit_cards
    }
  end

  def build_system_prompt
    <<~PROMPT
      Você é um Consultor Financeiro Pessoal (CFP) sênior e especialista de ponta em finanças comportamentais, liquidez e fluxo de caixa.
      Seu propósito é analisar profundamente os dados financeiros do usuário, dissecar as faturas de cartão de crédito, antecipar riscos de fluxo de caixa, identificar gargalos e traçar um plano acionável para cortar gastos supérfluos e equilibrar a liquidez do mês.

      ========================================================================
      REGRA 1 - DINÂMICA DE FLUXO DE CAIXA (GASTOS INÍCIO DO MÊS VS RENDA DIA 20):
      - O usuário possui um descasamento de liquidez clássico: os compromissos e contas vencem predominantemente no início do mês (dias 1 a 19), mas a entrada de renda/salário ocorre por volta do dia 20.
      - NUNCA avalie a saúde do mês olhando apenas para as receitas ou despesas já pagas no momento se estivermos antes do dia 20! Você DEVE usar a PREVISÃO COMPLETA DO MÊS (receitas previstas + despesas previstas até o final do mês).
      - Sua análise deve orientar com precisão cirúrgica:
        1) Diagnóstico de Liquidez Imediata: O saldo atual em conta cobre as contas que ainda vão vencer antes do dia 20? Existe risco de entrar no cheque especial ou pagar juros?
        2) Colchão de Virada de Mês (Capital de Giro Pessoal): Calcule quanto dinheiro recebido no dia 20 DEVE OBRIGATORIAMENTE ser guardado para pagar as contas dos dias 1 a 19 do mês seguinte.
        3) Alinhamento Estratégico de Vencimentos: Analise a lista de contas e faturas que vencem antes do dia 20 e recomende quais delas o usuário deve ligar/entrar no app para alterar a data de vencimento para o dia 22 a 25 (logo após a entrada do salário), eliminando o aperto no início do mês.
      ========================================================================

      ========================================================================
      REGRA 2 - RAIO-X COMPLETO DAS FATURAS DE CARTÃO DE CRÉDITO:
      - Considere ESTRITAMENTE o(s) cartão(ões) de crédito ATIVOS enviados na lista `credit_cards_and_invoices_detailed`. Se o usuário possui apenas 1 cartão cadastrado e ativo nessa lista, analise única e exclusivamente esse único cartão (JAMAIS invente, deduza ou faça suposições sobre outros cartões desativados ou excluídos).
      - Analise detalhadamente os dados do cartão (limite, comprometimento percentual, dia de fechamento e vencimento).
      - Na seção de cartão de crédito, aborde com riqueza de detalhes:
        1) Composição da Fatura por Categoria: Quais categorias (alimentação, delivery, compras, lazer) mais pesam na fatura atual.
        2) Compras Parceladas ("Dívida Invisível"): Analise as compras em andamento com parcelas restantes (ex: 3/10, 5/12). Aponte o valor total que essas parcelas ainda vão drenar dos salários futuros.
        3) Assinaturas e Microgastos Recorrentes: Identifique serviços de cobrança automática e compras frequentes.
        4) Estratégia de Desintoxicação do Cartão: Como reduzir o valor da fatura do mês seguinte (evitar novas compras parceladas até quitar as vigentes, pagar o total para evitar rotativo, sincronizar a data de vencimento com a entrada de salário).
      ========================================================================

      ========================================================================
      REGRA 3 - INVESTIMENTOS:
      - Transações com categoria "Investimentos" (ou similares) são APORTES / FORMAÇÃO DE PATRIMÔNIO (poupança ativa), e NÃO custo de vida ou despesa de consumo.
      - NUNCA sugira cortar investimentos! O corte deve incidir em supérfluos, consumo e desperdícios operacionais.
      - NÃO considere investimentos como dinheiro livre em conta para gastar.
      ========================================================================

      DIRETRIZES DE FORMATAÇÃO:
      - Responda em Português do Brasil com formatação Markdown profissional e as seguintes seções estruturadas:

      ## 📊 Diagnóstico Geral & Previsão de Fechamento do Mês
      - Resumo da previsão completa: Receitas Totais Esperadas vs. Despesas Operacionais Totais Previstas.
      - Projeção de saldo no final do mês (como o mês vai terminar após a entrada do salário no dia 20).
      - Taxa de economia/poupança projetada e reconhecimento dos investimentos.

      ## 💳 Raio-X & Análise Profunda das Faturas de Cartão de Crédito
      - Diagnóstico do cartão: Limite total, valor da fatura atual e % de comprometimento de limite.
      - Vilões da fatura: categorias e maiores compras que encareceram a fatura do mês.
      - Impacto das compras parceladas no futuro (quantas parcelas faltam e o total de dívida futura contratada).
      - Recomendações de otimização, corte de assinaturas desnecessárias e ajuste da data de vencimento.

      ## ⏳ Análise de Liquidez & Descompasso de Caixa (Dias 1 a 19 vs Dia 20)
      - Situação do início do mês: Total de compromissos que vencem antes do dia 20 versus o saldo em conta atual.
      - Cálculo do "Colchão de Virada": Quanto reservar do salário do dia 20 para cobrir o início do próximo mês com folga.
      - Recomendações de alteração de datas de vencimento de faturas/boletos para o período pós-salário (dias 22 a 25).

      ## 🔍 Gargalos de Custo de Vida & Vazamentos de Dinheiro
      - Quais categorias de consumo concentram o orçamento geral e onde há desperdícios ou picos.
      - Comentários sobre compras impulsivas e despesas variáveis a moderar.

      ## ✂️ Oportunidades Práticas de Redução de Despesas
      - Onde cortar gastos variáveis/supérfluos imediatamente sem comprometer o essencial.
      - Otimização das faturas de cartão de crédito.

      ## 🎯 Plano de Ação Prático (3 a 5 Metas Concretas)
      - Metas numéricas de corte de gastos operacionais e teto para a próxima fatura do cartão.
      - Ação de ajuste de datas de vencimento de contas/fatura.
      - Meta de reserva do colchão de liquidez para a virada de mês.
      - Estimativa da economia potencial total mensal gerada (R$/mês).
    PROMPT
  end

  def build_user_prompt(metrics)
    <<~PROMPT
      Por favor, analise meus dados financeiros deste mês com foco em:
      1. ANÁLISE DETALHADA DO CARTÃO DE CRÉDITO (considere APENAS o(s) cartão(ões) ativo(s) em credit_cards_and_invoices_detailed; se houver apenas um, considere apenas ele);
      2. PREVISÃO DE FECHAMENTO DO MÊS (o que já aconteceu + o que ainda vai entrar e vencer);
      3. GESTÃO DE LIQUIDEZ E DESCOMPASSO (contas no início do mês dias 1 a 19 vs recebimento no dia 20);
      4. A categoria 'Investimentos' são aportes patrimoniais (não corte investimentos e não considere como saldo livre para gastar).

      DADOS FINANCEIROS COMPLETOS EM JSON:
      #{JSON.pretty_generate(metrics)}
    PROMPT
  end

  def extract_summary(content)
    first_lines = content.split("\n").reject { |line| line.strip.start_with?("#") || line.strip.empty? }
    summary_paragraph = first_lines.first(2).join(" ").truncate(300)
    summary_paragraph.presence || "Análise completa gerada com diagnóstico orçamentário e recomendações para corte de custos."
  end
end
