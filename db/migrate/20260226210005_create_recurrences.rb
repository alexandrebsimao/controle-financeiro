class CreateRecurrences < ActiveRecord::Migration[8.1]
  def change
    create_table :recurrences do |t|
      t.references :user, null: false, foreign_key: true
      t.references :bank_account, null: false, foreign_key: true
      t.references :category, null: true, foreign_key: true
      t.string :title, null: false
      t.string :transaction_type, null: false
      t.string :payment_method
      t.decimal :amount, precision: 15, scale: 2, null: false
      t.string :frequency, null: false
      t.integer :interval, default: 1
      t.date :start_date, null: false
      t.date :end_date
      t.integer :total_occurrences
      t.integer :occurrences_generated, default: 0
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :recurrences, [:user_id, :active, :start_date]
  end
end
