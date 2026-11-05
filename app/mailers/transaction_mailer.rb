class TransactionMailer < ApplicationMailer
  def due_transactions_notification(user)
    @user = user
    @due_transactions = DueTransactionsService.call(user)
    
    mail(
      to: user.email,
      subject: "Movimentações a vencer - #{I18n.l(Date.today, format: :long)}"
    )
  end
end
