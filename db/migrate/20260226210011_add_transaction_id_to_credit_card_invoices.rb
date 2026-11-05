class AddTransactionIdToCreditCardInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :credit_card_invoices, :transaction_id, :bigint
    add_index :credit_card_invoices, :transaction_id
    add_foreign_key :credit_card_invoices, :transactions, column: :transaction_id
  end
end
