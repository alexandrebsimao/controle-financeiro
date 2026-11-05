class AddTransferFieldsToTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :transactions, :destination_bank_account_id, :bigint
    add_column :transactions, :related_transfer_id, :bigint
    
    add_index :transactions, :destination_bank_account_id
    add_index :transactions, :related_transfer_id
    
    add_foreign_key :transactions, :bank_accounts, column: :destination_bank_account_id
    add_foreign_key :transactions, :transactions, column: :related_transfer_id
  end
end
