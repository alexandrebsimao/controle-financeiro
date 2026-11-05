class AddOnDeleteNullifyToTransactionRelatedTransferFk < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :transactions, column: :related_transfer_id
    add_foreign_key :transactions, :transactions, column: :related_transfer_id, on_delete: :nullify
  end
end
