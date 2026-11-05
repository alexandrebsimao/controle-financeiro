class InvoicePaymentService
  def initialize(invoice, bank_account_id = nil)
    @invoice = invoice
    @credit_card = invoice.credit_card
    @bank_account_id = bank_account_id
    @bank_account = bank_account_id ? BankAccount.find(bank_account_id) : @credit_card.bank_account
  end
  
  class Result
    attr_reader :success, :message
    
    def initialize(success, message = "")
      @success = success
      @message = message
    end
    
    def success?
      @success
    end
  end

  def call
    return Result.new(false, "Fatura já foi paga") if @invoice.paid?
    return Result.new(false, "Nenhuma conta bancária selecionada") if @bank_account.blank?
    return Result.new(false, "Saldo insuficiente") if @bank_account.balance < @invoice.total_amount

    ActiveRecord::Base.transaction do
      transaction = Transaction.create!(
        user: @credit_card.user,
        bank_account: @bank_account,
        title: "Fatura #{@credit_card.name} — #{@invoice.reference_label}",
        transaction_type: "expense",
        payment_method: "credit_card_bill",
        amount: @invoice.total_amount,
        due_date: @invoice.due_date,
        paid: true,
        paid_at: Date.today,
        credit_card: @credit_card
      )

      @invoice.update!(
        paid: true,
        paid_at: Date.today,
        transaction_id: transaction.id
      )
      
      @bank_account.decrement!(:balance, @invoice.total_amount)
    end

    Result.new(true, "Fatura paga com sucesso")
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "InvoicePaymentService failed: Bank account not found - #{e.message}"
    Result.new(false, "Conta bancária não encontrada")
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "InvoicePaymentService failed: #{e.message}"
    Result.new(false, "Erro ao pagar a fatura: #{e.message}")
  rescue => e
    Rails.logger.error "InvoicePaymentService failed with unexpected error: #{e.message}"
    Result.new(false, "Erro inesperado ao pagar a fatura")
  end
end
