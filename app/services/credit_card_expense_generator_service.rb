class CreditCardExpenseGeneratorService
  def initialize(purchase)
    @purchase = purchase
    @credit_card = purchase.credit_card
  end

  def call
    @purchase.installments.times do |i|
      installment_number = i + 1
      # Calculate which month this installment falls in
      base_date = @purchase.purchased_at
      expense_date = base_date + i.months

      # Find or create the invoice for this month
      ref = @credit_card.reference_month_for(expense_date)
      invoice = find_or_create_invoice(ref[:year], ref[:month], expense_date)

      CreditCardExpense.create!(
        credit_card_purchase: @purchase,
        invoice: invoice,
        installment_number: installment_number,
        amount: @purchase.installment_amount,
        due_date: expense_date
      )
    end
  end

  private

  def find_or_create_invoice(year, month, reference_date)
    InvoiceCreatorService.new(@credit_card).find_or_create(year, month, reference_date)
  end
end
