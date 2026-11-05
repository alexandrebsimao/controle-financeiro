class AddAiProviderToUsersAndFinancialInsights < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :preferred_ai_provider, :string, default: "groq"
    add_column :users, :groq_model, :string
    add_column :users, :gemini_model, :string
    add_column :users, :custom_groq_api_key, :string
    add_column :users, :custom_gemini_api_key, :string
    add_column :financial_insights, :ai_provider, :string, default: "groq"
  end
end
