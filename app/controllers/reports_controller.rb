# frozen_string_literal: true

class ReportsController < ApplicationController
  before_action :authenticate_user!

  def index
    @period = params[:period].presence || "6_months"
    @service = FinancialReportsService.new(current_user, period: @period)
    @report_data = @service.call

    respond_to do |format|
      format.html
      format.csv do
        send_data @service.to_csv,
                  filename: "relatorio_financeiro_#{Date.today.strftime('%Y%m%d')}.csv",
                  type: "text/csv; charset=utf-8"
      end
    end
  end
end
