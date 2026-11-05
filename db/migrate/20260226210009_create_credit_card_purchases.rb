class CreateCreditCardPurchases < ActiveRecord::Migration[8.1]
  def change
    create_table :credit_card_purchases do |t|
      t.references :credit_card, null: false, foreign_key: true
      t.references :category, null: true, foreign_key: true
      t.string :title, null: false
      t.decimal :total_amount, precision: 15, scale: 2, null: false
      t.integer :installments, default: 1
      t.date :purchased_at, null: false
      t.boolean :auto_categorized, default: false
      t.text :notes

      t.timestamps
    end

    add_index :credit_card_purchases, [:credit_card_id, :purchased_at]
  end
end
