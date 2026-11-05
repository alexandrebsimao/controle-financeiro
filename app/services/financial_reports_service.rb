# frozen_string_literal: true

class FinancialReportsService
  attr_reader :user, :period_months

  PERIOD_OPTIONS = {
    "3_months" => 3,
    "6_months" => 6,
    "12_months" => 12,
    "current_year" => (Date.today.month)
  }.freeze

  def initialize(user, period: "6_months")
    @user = user
    @period_months = PERIOD_OPTIONS[period] || 6
  end

  def call
    {
      kpis: build_kpis,
      savings_rate_trend: build_savings_rate_trend,
      category_evolution: build_category_evolution,
      rule_50_30_20: build_50_30_20_analysis,
      yoy_comparison: build_yoy_comparison,
      top_expenses: build_top_expenses,
      future_commitment: build_future_commitment,
      daily_cash_flow: build_daily_cash_flow
    }
  end

  # ==========================================
  # 1. KPIs CONSOLIDADOS
  # ==========================================
  def build_kpis
    total_balance = user.bank_accounts.active.sum(:balance).to_d

    # Média de despesas mensais nos últimos N meses
    past_months = (0...period_months).map do |i|
      m_start = i.months.ago.beginning_of_month
      m_end = m_start.end_of_month
      user.transactions.expense.paid.for_period(m_start, m_end).sum(:amount).to_d
    end
    avg_monthly_expense = past_months.any? ? (past_months.sum / past_months.size) : 0.to_d

    # Runway da Reserva de Emergência
    runway_months = if avg_monthly_expense > 0
                      (total_balance / avg_monthly_expense).to_f.round(1)
                    else
                      total_balance > 0 ? 12.0 : 0.0
                    end

    # Taxa Média de Poupança
    savings_data = build_savings_rate_trend
    avg_savings_rate = if savings_data[:rates].any?
                         (savings_data[:rates].sum / savings_data[:rates].size).round(1)
                       else
                         0.0
                       end

    # Comprometimento do próximo mês
    next_month_start = 1.month.from_now.beginning_of_month.to_date
    next_month_end = next_month_start.end_of_month
    
    next_invoices = user.active_credit_card_invoices.where(due_date: next_month_start..next_month_end).sum(:total_amount).to_d
    next_card_expenses = CreditCardExpense.joins(credit_card_purchase: :credit_card)
                                          .where(credit_cards: { user_id: user.id, active: true })
                                          .where(due_date: next_month_start..next_month_end)
                                          .sum(:amount).to_d
    next_card_total = [next_invoices, next_card_expenses].max

    next_fixed_expenses = user.recurrences.active.where(transaction_type: "expense").sum(:amount).to_d
    next_scheduled_expenses = user.transactions.expense.unpaid.for_period(next_month_start, next_month_end).sum(:amount).to_d
    total_next_committed = next_card_total + next_fixed_expenses + next_scheduled_expenses

    expected_income = user.recurrences.active.where(transaction_type: "income").sum(:amount).to_d
    if expected_income.zero?
      # Usa média histórica de receitas
      past_incomes = (0...period_months).map do |i|
        m_start = i.months.ago.beginning_of_month
        m_end = m_start.end_of_month
        user.transactions.income.paid.for_period(m_start, m_end).sum(:amount).to_d
      end
      expected_income = past_incomes.any? ? (past_incomes.sum / past_incomes.size) : 0.to_d
    end

    next_commitment_rate = if expected_income > 0
                             ((total_next_committed / expected_income) * 100).to_f.round(1)
                           else
                             0.0
                           end

    # Saldo Mínimo Previsto nos próximos 60 dias
    cash_flow = build_daily_cash_flow
    lowest_projected_balance = cash_flow[:balances].min || total_balance.to_f

    # Total investido no período completo
    full_period_start = (period_months - 1).months.ago.beginning_of_month
    full_period_end = Date.today.end_of_month
    total_invested_period = user.transactions.investment.paid.for_period(full_period_start, full_period_end).sum(:amount).to_d

    {
      total_balance: total_balance.to_f.round(2),
      avg_monthly_expense: avg_monthly_expense.to_f.round(2),
      runway_months: runway_months,
      avg_savings_rate: avg_savings_rate,
      total_invested_period: total_invested_period.to_f.round(2),
      next_month_committed: total_next_committed.to_f.round(2),
      next_month_income: expected_income.to_f.round(2),
      next_month_commitment_rate: next_commitment_rate,
      lowest_projected_balance: lowest_projected_balance.round(2),
      danger_of_negative_balance: lowest_projected_balance < 0
    }
  end

  # ==========================================
  # 2. HISTÓRICO: TAXA DE POUPANÇA E BALANÇO
  # ==========================================
  def build_savings_rate_trend
    labels = []
    incomes = []
    expenses = []
    investments = []
    savings = []
    rates = []

    (period_months - 1).downto(0) do |i|
      m_start = i.months.ago.beginning_of_month
      m_end = m_start.end_of_month
      labels << m_start.strftime("%b/%Y")

      inc = user.transactions.income.paid.for_period(m_start, m_end).sum(:amount).to_d
      exp = user.transactions.expense.paid.for_period(m_start, m_end).sum(:amount).to_d
      inv = user.transactions.investment.paid.for_period(m_start, m_end).sum(:amount).to_d
      net = inc - exp

      rate = inc > 0 ? ((net / inc) * 100.0).to_f.round(1) : 0.0

      incomes << inc.to_f.round(2)
      expenses << exp.to_f.round(2)
      investments << inv.to_f.round(2)
      savings << net.to_f.round(2)
      rates << rate
    end

    {
      labels: labels,
      incomes: incomes,
      expenses: expenses,
      investments: investments,
      savings: savings,
      rates: rates
    }
  end

  # ==========================================
  # 3. HISTÓRICO: EVOLUÇÃO POR CATEGORIA
  # ==========================================
  def build_category_evolution
    # Top 5 categorias de despesas no período completo
    full_start = (period_months - 1).months.ago.beginning_of_month
    full_end = Date.today.end_of_month

    top_categories = user.transactions
                         .expense
                         .paid
                         .for_period(full_start, full_end)
                         .joins(:category)
                         .group("categories.id", "categories.name", "categories.color")
                         .select("categories.id, categories.name, categories.color, SUM(transactions.amount) as total_spent")
                         .order("total_spent DESC")
                         .limit(5)

    month_labels = []
    (period_months - 1).downto(0) do |i|
      month_labels << i.months.ago.beginning_of_month.strftime("%b/%Y")
    end

    datasets = top_categories.map do |cat|
      data_points = []
      (period_months - 1).downto(0) do |i|
        m_start = i.months.ago.beginning_of_month
        m_end = m_start.end_of_month

        spent = user.transactions
                    .expense
                    .paid
                    .where(category_id: cat.id)
                    .for_period(m_start, m_end)
                    .sum(:amount)
                    .to_d
                    .to_f
                    .round(2)

        data_points << spent
      end

      {
        id: cat.id,
        name: cat.name,
        color: cat.color.presence || "#6366f1",
        data: data_points
      }
    end

    {
      labels: month_labels,
      datasets: datasets
    }
  end

  # ==========================================
  # 4. REGRA 50/30/20 (NECESSIDADES, DESEJOS, RESERVA)
  # ==========================================
  def build_50_30_20_analysis
    period_start = (period_months - 1).months.ago.beginning_of_month
    period_end = Date.today.end_of_month

    total_income = user.transactions.income.paid.for_period(period_start, period_end).sum(:amount).to_d
    total_expense = user.transactions.expense.paid.for_period(period_start, period_end).sum(:amount).to_d
    total_invested = user.transactions.investment.paid.for_period(period_start, period_end).sum(:amount).to_d
    total_saved = [total_income - total_expense, total_invested].max

    # Classificação por palavras-chave ou padrões comuns de categorias brasileiras
    necessities_keywords = %w[moradia aluguel condomínio luz energia água internet saúde mercado alimentação transporte combustível farmácia educação plano]
    lifestyle_keywords = %w[lazer restaurante bar compras viagem streaming cinema delivery compras vestuário hobby games assinatura]

    expenses_by_cat = user.transactions
                          .expense
                          .paid
                          .for_period(period_start, period_end)
                          .joins(:category)
                          .group("categories.name")
                          .sum(:amount)

    necessities_total = 0.to_d
    lifestyle_total = 0.to_d

    expenses_by_cat.each do |cat_name, amount|
      normalized = cat_name.to_s.downcase
      if necessities_keywords.any? { |kw| normalized.include?(kw) }
        necessities_total += amount.to_d
      elsif lifestyle_keywords.any? { |kw| normalized.include?(kw) }
        lifestyle_total += amount.to_d
      else
        # Divide padrão 60% necessidades / 40% estilo de vida para neutros
        necessities_total += amount.to_d * 0.6
        lifestyle_total += amount.to_d * 0.4
      end
    end

    base_total = [total_income, (necessities_total + lifestyle_total + total_saved)].max
    return { necessities_pct: 50, lifestyle_pct: 30, savings_pct: 20, values: [0, 0, 0] } if base_total.zero?

    necessities_pct = ((necessities_total / base_total) * 100).to_f.round(1)
    lifestyle_pct = ((lifestyle_total / base_total) * 100).to_f.round(1)
    savings_pct = ((total_saved / base_total) * 100).to_f.round(1)

    {
      necessities_amount: necessities_total.to_f.round(2),
      lifestyle_amount: lifestyle_total.to_f.round(2),
      savings_amount: total_saved.to_f.round(2),
      invested_amount: total_invested.to_f.round(2),
      necessities_pct: necessities_pct,
      lifestyle_pct: lifestyle_pct,
      savings_pct: savings_pct,
      ideal: { necessities: 50, lifestyle: 30, savings: 20 }
    }
  end

  # ==========================================
  # 5. COMPARATIVO ANO A ANO (YoY)
  # ==========================================
  def build_yoy_comparison
    current_start = Date.today.beginning_of_month
    current_end = Date.today.end_of_month

    last_year_start = 1.year.ago.beginning_of_month
    last_year_end = 1.year.ago.end_of_month

    current_income = user.transactions.income.paid.for_period(current_start, current_end).sum(:amount).to_d
    current_expense = user.transactions.expense.paid.for_period(current_start, current_end).sum(:amount).to_d
    current_net = current_income - current_expense

    last_year_income = user.transactions.income.paid.for_period(last_year_start, last_year_end).sum(:amount).to_d
    last_year_expense = user.transactions.expense.paid.for_period(last_year_start, last_year_end).sum(:amount).to_d
    last_year_net = last_year_income - last_year_expense

    income_change = last_year_income > 0 ? (((current_income - last_year_income) / last_year_income) * 100).round(1) : 0.0
    expense_change = last_year_expense > 0 ? (((current_expense - last_year_expense) / last_year_expense) * 100).round(1) : 0.0

    {
      current_month: current_start.strftime("%B/%Y"),
      last_year_month: last_year_start.strftime("%B/%Y"),
      current_income: current_income.to_f.round(2),
      last_year_income: last_year_income.to_f.round(2),
      income_change_pct: income_change,
      current_expense: current_expense.to_f.round(2),
      last_year_expense: last_year_expense.to_f.round(2),
      expense_change_pct: expense_change,
      current_net: current_net.to_f.round(2),
      last_year_net: last_year_net.to_f.round(2)
    }
  end

  # ==========================================
  # 6. TOP MAIORES GASTOS (PARETO)
  # ==========================================
  def build_top_expenses
    period_start = (period_months - 1).months.ago.beginning_of_month
    period_end = Date.today.end_of_month

    user.transactions
        .expense
        .paid
        .for_period(period_start, period_end)
        .includes(:category, :bank_account)
        .order(amount: :desc)
        .limit(8)
  end

  # ==========================================
  # 7. PREVISÃO: COMPROMETIMENTO DE RENDA FUTURA
  # ==========================================
  def build_future_commitment
    labels = []
    credit_card_commitments = []
    fixed_recurrences = []
    scheduled_expenses = []
    expected_incomes = []
    free_margins = []
    commitment_rates = []

    # Renda mensal esperada (baseada em recorrências de receita ou média recente)
    fixed_monthly_income = user.recurrences.active.where(transaction_type: "income").sum(:amount).to_d
    if fixed_monthly_income.zero?
      recent_incomes = (0..2).map do |i|
        m_start = i.months.ago.beginning_of_month
        m_end = m_start.end_of_month
        user.transactions.income.paid.for_period(m_start, m_end).sum(:amount).to_d
      end
      fixed_monthly_income = recent_incomes.any? ? (recent_incomes.sum / recent_incomes.size) : 0.to_d
    end

    1.upto(6) do |i|
      m_start = i.months.from_now.beginning_of_month.to_date
      m_end = m_start.end_of_month
      labels << m_start.strftime("%b/%Y")

      # 1. Parcelas de Cartão de Crédito
      invoices_amount = user.active_credit_card_invoices.where(due_date: m_start..m_end).sum(:total_amount).to_d
      installment_expenses = CreditCardExpense.joins(credit_card_purchase: :credit_card)
                                              .where(credit_cards: { user_id: user.id, active: true })
                                              .where(due_date: m_start..m_end)
                                              .sum(:amount).to_d
      card_total = [invoices_amount, installment_expenses].max

      # 2. Despesas Fixas Recorrentes
      fixed_rec = user.recurrences.active.where(transaction_type: "expense").sum(:amount).to_d

      # 3. Outras despesas pendentes agendadas
      sched_exp = user.transactions.ignore_transfers.expense.unpaid.for_period(m_start, m_end).sum(:amount).to_d

      total_committed = card_total + fixed_rec + sched_exp
      income = fixed_monthly_income
      margin = income - total_committed
      rate = income > 0 ? ((total_committed / income) * 100.0).round(1) : 0.0

      credit_card_commitments << card_total.to_f.round(2)
      fixed_recurrences << fixed_rec.to_f.round(2)
      scheduled_expenses << sched_exp.to_f.round(2)
      expected_incomes << income.to_f.round(2)
      free_margins << margin.to_f.round(2)
      commitment_rates << rate
    end

    {
      labels: labels,
      credit_cards: credit_card_commitments,
      recurrences: fixed_recurrences,
      scheduled: scheduled_expenses,
      expected_income: expected_incomes,
      free_margin: free_margins,
      rates: commitment_rates
    }
  end

  # ==========================================
  # 8. PREVISÃO: FLUXO DE CAIXA DIÁRIO (PRÓXIMOS 60 DIAS)
  # ==========================================
  def build_daily_cash_flow
    days_to_project = 60
    start_date = Date.today
    end_date = start_date + days_to_project.days

    current_balance = user.bank_accounts.active.sum(:balance).to_d

    # Carregar transações pendentes futuras agrupadas por data de vencimento
    future_transactions = user.transactions
                              .unpaid
                              .where(due_date: start_date..end_date)
                              .group(:due_date, :transaction_type)
                              .sum(:amount)

    # Carregar faturas de cartão pendentes agrupadas por data de vencimento
    future_invoices = user.active_credit_card_invoices
                          .unpaid
                          .where(due_date: start_date..end_date)
                          .group(:due_date)
                          .sum(:total_amount)

    # Carregar parcelas de cartão caso não haja fatura fechada
    future_installments = CreditCardExpense.joins(credit_card_purchase: :credit_card)
                                           .where(credit_cards: { user_id: user.id, active: true })
                                           .where(due_date: start_date..end_date)
                                           .group(:due_date)
                                           .sum(:amount)

    labels = []
    balances = []
    inflows = []
    outflows = []

    (start_date..end_date).each do |date|
      day_income = future_transactions[[date, "income"]].to_d
      day_expense = future_transactions[[date, "expense"]].to_d
      day_investment = future_transactions[[date, "investment"]].to_d
      
      invoice_expense = future_invoices[date].to_d
      installment_expense = future_installments[date].to_d
      card_expense = [invoice_expense, installment_expense].max

      total_outflow = day_expense + day_investment + card_expense

      current_balance += (day_income - total_outflow)

      labels << date.strftime("%d/%m")
      balances << current_balance.to_f.round(2)
      inflows << day_income.to_f.round(2)
      outflows << total_outflow.to_f.round(2)
    end

    {
      labels: labels,
      balances: balances,
      inflows: inflows,
      outflows: outflows
    }
  end

  # ==========================================
  # EXPORTAÇÃO CSV CONSOLIDADA
  # ==========================================
  def to_csv
    require "csv"

    CSV.generate(headers: true, col_sep: ";") do |csv|
      csv << ["=== RELATÓRIO FINANCEIRO CONSOLIDADO ==="]
      csv << ["Data de Geração", Time.current.strftime("%d/%m/%Y %H:%M")]
      csv << ["Usuário", user.name]
      csv << []

      # Indicadores
      kpi = build_kpis
      csv << ["=== INDICADORES DE SAÚDE FINANCEIRA ==="]
      csv << ["Métrica", "Valor"]
      csv << ["Saldo Consolidado em Contas", "R$ #{kpi[:total_balance]}"]
      csv << ["Custo de Vida Médio Mensal", "R$ #{kpi[:avg_monthly_expense]}"]
      csv << ["Reserva de Emergência (Runway)", "#{kpi[:runway_months]} meses"]
      csv << ["Taxa Média de Poupança", "#{kpi[:avg_savings_rate]}%"]
      csv << ["Total Aportado em Investimentos (Período)", "R$ #{kpi[:total_invested_period]}"]
      csv << ["Comprometimento no Próximo Mês", "#{kpi[:next_month_commitment_rate]}% (R$ #{kpi[:next_month_committed]})"]
      csv << ["Menor Saldo Previsto (Próx 60 dias)", "R$ #{kpi[:lowest_projected_balance]}"]
      csv << []

      # Histórico Mensal
      csv << ["=== HISTÓRICO MÊS A MÊS ==="]
      csv << ["Mês", "Receitas (R$)", "Despesas (R$)", "Investimentos (R$)", "Poupança Líquida (R$)", "Taxa de Poupança (%)"]
      savings_trend = build_savings_rate_trend
      savings_trend[:labels].each_with_index do |lbl, idx|
        csv << [lbl, savings_trend[:incomes][idx], savings_trend[:expenses][idx], savings_trend[:investments][idx], savings_trend[:savings][idx], "#{savings_trend[:rates][idx]}%"]
      end
      csv << []

      # Previsão Futura
      csv << ["=== PREVISÃO DE COMPROMETIMENTO FUTURO ==="]
      csv << ["Mês", "Cartão de Crédito (R$)", "Contas Fixas (R$)", "Outros Agendados (R$)", "Renda Prevista (R$)", "Margem Livre (R$)", "% Comprometido"]
      future = build_future_commitment
      future[:labels].each_with_index do |lbl, idx|
        csv << [
          lbl,
          future[:credit_cards][idx],
          future[:recurrences][idx],
          future[:scheduled][idx],
          future[:expected_income][idx],
          future[:free_margin][idx],
          "#{future[:rates][idx]}%"
        ]
      end
    end
  end
end
