class DashboardController < ApplicationController
  def index
    @bank_accounts = current_user.bank_accounts.active
    @total_balance = @bank_accounts.sum(:balance)

    period_start = Date.today.beginning_of_month
    period_end = Date.today.end_of_month

    @monthly_income = current_user.transactions
      .income.paid
      .for_period(period_start, period_end)
      .sum(:amount)

    @monthly_expenses = current_user.transactions
      .expense.paid
      .for_period(period_start, period_end)
      .sum(:amount)

    @monthly_investments = current_user.transactions
      .investment.paid
      .for_period(period_start, period_end)
      .sum(:amount)

    # Despesas por categoria do mês
    @expenses_by_category = current_user.transactions
      .expense.paid
      .for_period(period_start, period_end)
      .joins(:category)
      .group("categories.name")
      .sum(:amount)
      .sort_by { |_, amount| -amount }
      .to_h
      .transform_values { |v| v.to_d.to_f.round(2) }

    # Últimos 6 meses: entrada e saída (ordem cronológica)
    @monthly_trend = {}
    (5).downto(0) do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = month_start.end_of_month
      month_key = month_start.strftime("%b/%Y")
      
      income = current_user.transactions
        .income.paid
        .for_period(month_start, month_end)
        .sum(:amount).to_d.to_f.round(2)
      
      expenses = current_user.transactions
        .expense.paid
        .for_period(month_start, month_end)
        .sum(:amount).to_d.to_f.round(2)
      
      @monthly_trend[month_key] = { income: income, expenses: expenses }
    end

    # Projeção dos próximos 6 meses baseada em movimentações futuras pendentes
    @expense_forecast = {}
    projected_balance = @total_balance.to_d

    1.upto(6) do |i|
      month_start = i.months.from_now.beginning_of_month.to_date
      month_end = month_start.end_of_month
      month_key = month_start.strftime("%b/%Y")

      forecast_income = current_user.transactions
        .ignore_transfers
        .income
        .unpaid
        .for_period(month_start, month_end)
        .sum(:amount)
        .to_d

      forecast_expenses = current_user.transactions
        .ignore_transfers
        .expense
        .unpaid
        .for_period(month_start, month_end)
        .sum(:amount)
        .to_d

      forecast_investments = current_user.transactions
        .ignore_transfers
        .investment
        .unpaid
        .for_period(month_start, month_end)
        .sum(:amount)
        .to_d

      forecast_unpaid_invoices = current_user.active_credit_card_invoices
        .unpaid
        .where(due_date: month_start..month_end)
        .sum(:total_amount)
        .to_d

      total_forecast_expenses = forecast_expenses + forecast_unpaid_invoices

      projected_balance += forecast_income - (total_forecast_expenses + forecast_investments)

      @expense_forecast[month_key] = {
        income: forecast_income.to_f.round(2),
        expenses: total_forecast_expenses.to_f.round(2),
        projected_balance: projected_balance.to_f.round(2)
      }
    end

    @upcoming_transactions = current_user.transactions
      .upcoming
      .includes(:bank_account, :category)
      .limit(10)

    @overdue_transactions = current_user.transactions
      .overdue
      .includes(:bank_account, :category)
      .limit(5)

    @upcoming_invoices = CreditCardInvoice
      .joins(:credit_card)
      .where(credit_cards: { user_id: current_user.id, active: true })
      .upcoming
      .includes(:credit_card)
      .limit(5)
  end
end
