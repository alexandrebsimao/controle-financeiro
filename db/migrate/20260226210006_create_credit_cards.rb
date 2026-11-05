class CreateCreditCards < ActiveRecord::Migration[8.1]
  def change
    create_table :credit_cards do |t|
      t.references :user, null: false, foreign_key: true
      t.references :bank_account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :brand
      t.decimal :credit_limit, precision: 15, scale: 2
      t.integer :closing_day, null: false
      t.integer :due_day, null: false
      t.string :color
      t.boolean :active, default: true

      t.timestamps
    end
  end
end
