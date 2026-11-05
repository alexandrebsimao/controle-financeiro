class CreateCreditCardExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :credit_card_expenses do |t|
      t.references :credit_card_purchase, null: false, foreign_key: true
      t.bigint :invoice_id
      t.integer :installment_number, null: false
      t.decimal :amount, precision: 15, scale: 2, null: false
      t.date :due_date, null: false

      t.datetime :created_at, null: false
    end

    add_index :credit_card_expenses, :invoice_id
    add_index :credit_card_expenses, :due_date

    add_foreign_key :credit_card_expenses, :credit_card_invoices, column: :invoice_id
  end
end
