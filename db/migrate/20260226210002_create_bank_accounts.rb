class CreateBankAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :bank_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :bank_name
      t.string :account_type, default: "checking"
      t.decimal :balance, precision: 15, scale: 2, default: 0.0
      t.string :currency, default: "BRL"
      t.string :color
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :bank_accounts, [:user_id, :active]
  end
end
