class InvoiceCreatorService
  def initialize(credit_card)
    @credit_card = credit_card
  end

  def find_or_create(year, month, reference_date = nil)
    invoice = @credit_card.credit_card_invoices.find_by(reference_year: year, reference_month: month)
    return invoice if invoice

    closing_date = Date.new(year, month, [@credit_card.closing_day, Date.new(year, month, -1).day].min)
    due_date = build_due_date(closing_date)

    @credit_card.credit_card_invoices.create!(
      reference_month: month,
      reference_year: year,
      closing_date: closing_date,
      due_date: due_date,
      total_amount: 0.0
    )
  end

  def generate_future_invoices(months_ahead = 12)
    today = Date.today
    months_ahead.times do |i|
      target = today + i.months
      find_or_create(target.year, target.month)
    end
  end

  private

  def build_due_date(closing_date)
    # Due day is in the next month after closing
    next_month = closing_date
    day = [@credit_card.due_day, next_month.end_of_month.day].min
    Date.new(next_month.year, next_month.month, day)
  end
end
