class CreateFinancialInsights < ActiveRecord::Migration[8.1]
  def change
    create_table :financial_insights do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.string :period, null: false
      t.text :summary
      t.text :content, null: false
      t.jsonb :raw_metrics, default: {}
      t.string :model_used
      t.string :status, default: "completed"

      t.timestamps
    end

    add_index :financial_insights, [:user_id, :created_at]
  end
end
