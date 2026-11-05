class CreateCreditCardInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :credit_card_invoices do |t|
      t.references :credit_card, null: false, foreign_key: true
      t.integer :reference_month, null: false
      t.integer :reference_year, null: false
      t.date :closing_date, null: false
      t.date :due_date, null: false
      t.decimal :total_amount, precision: 15, scale: 2, default: 0.0
      t.boolean :paid, default: false
      t.date :paid_at

      t.timestamps
    end

    add_index :credit_card_invoices, [:credit_card_id, :reference_year, :reference_month], unique: true, name: "idx_invoices_card_year_month"
  end
end
