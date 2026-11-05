class CreateCategoryKeywords < ActiveRecord::Migration[8.1]
  def change
    create_table :category_keywords do |t|
      t.references :category, null: false, foreign_key: true
      t.string :keyword, null: false
      t.string :match_type, default: "contains"
      t.integer :priority, default: 0

      t.datetime :created_at, null: false
    end

    add_index :category_keywords, [:keyword, :match_type]
  end
end
