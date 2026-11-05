class AddIdempotencyKeyToTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :transactions, :idempotency_key, :string
    add_index :transactions, [:user_id, :idempotency_key], unique: true, where: "idempotency_key IS NOT NULL"
  end
end
