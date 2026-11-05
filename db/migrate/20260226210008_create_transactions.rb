class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :transactions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :bank_account, null: false, foreign_key: true
      t.references :category, null: true, foreign_key: true
      t.bigint :recurrence_id
      t.bigint :credit_card_id
      t.string :title, null: false
      t.text :notes
      t.string :transaction_type, null: false
      t.string :payment_method
      t.decimal :amount, precision: 15, scale: 2, null: false
      t.date :due_date, null: false
      t.date :paid_at
      t.boolean :paid, default: false
      t.boolean :auto_categorized, default: false
      t.integer :recurrence_index

      t.timestamps
    end

    add_index :transactions, [:user_id, :due_date]
    add_index :transactions, [:bank_account_id, :paid]
    add_index :transactions, :recurrence_id
    add_index :transactions, :credit_card_id

    add_foreign_key :transactions, :recurrences, column: :recurrence_id
    add_foreign_key :transactions, :credit_cards, column: :credit_card_id
  end
end
