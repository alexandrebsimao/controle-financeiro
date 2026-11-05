class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.references :user, null: true, foreign_key: true
      t.string :name, null: false
      t.string :transaction_type, default: "both"
      t.string :icon
      t.string :color
      t.bigint :parent_id

      t.timestamps
    end

    add_index :categories, :parent_id
    add_foreign_key :categories, :categories, column: :parent_id
  end
end
