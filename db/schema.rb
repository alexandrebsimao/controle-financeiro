# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_05_173000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "bank_accounts", force: :cascade do |t|
    t.string "account_type", default: "checking"
    t.boolean "active", default: true
    t.decimal "balance", precision: 15, scale: 2, default: "0.0"
    t.string "bank_name"
    t.string "color"
    t.datetime "created_at", null: false
    t.string "currency", default: "BRL"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "active"], name: "index_bank_accounts_on_user_id_and_active"
    t.index ["user_id"], name: "index_bank_accounts_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "color"
    t.datetime "created_at", null: false
    t.string "icon"
    t.string "name", null: false
    t.bigint "parent_id"
    t.string "transaction_type", default: "both"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["parent_id"], name: "index_categories_on_parent_id"
    t.index ["user_id"], name: "index_categories_on_user_id"
  end

  create_table "category_keywords", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.string "keyword", null: false
    t.string "match_type", default: "contains"
    t.integer "priority", default: 0
    t.index ["category_id"], name: "index_category_keywords_on_category_id"
    t.index ["keyword", "match_type"], name: "index_category_keywords_on_keyword_and_match_type"
  end

  create_table "credit_card_expenses", force: :cascade do |t|
    t.decimal "amount", precision: 15, scale: 2, null: false
    t.datetime "created_at", null: false
    t.bigint "credit_card_purchase_id", null: false
    t.date "due_date", null: false
    t.integer "installment_number", null: false
    t.bigint "invoice_id"
    t.index ["credit_card_purchase_id"], name: "index_credit_card_expenses_on_credit_card_purchase_id"
    t.index ["due_date"], name: "index_credit_card_expenses_on_due_date"
    t.index ["invoice_id"], name: "index_credit_card_expenses_on_invoice_id"
  end

  create_table "credit_card_invoices", force: :cascade do |t|
    t.date "closing_date", null: false
    t.datetime "created_at", null: false
    t.bigint "credit_card_id", null: false
    t.date "due_date", null: false
    t.boolean "paid", default: false
    t.date "paid_at"
    t.integer "reference_month", null: false
    t.integer "reference_year", null: false
    t.decimal "total_amount", precision: 15, scale: 2, default: "0.0"
    t.bigint "transaction_id"
    t.datetime "updated_at", null: false
    t.index ["credit_card_id", "reference_year", "reference_month"], name: "idx_invoices_card_year_month", unique: true
    t.index ["credit_card_id"], name: "index_credit_card_invoices_on_credit_card_id"
    t.index ["transaction_id"], name: "index_credit_card_invoices_on_transaction_id"
  end

  create_table "credit_card_purchases", force: :cascade do |t|
    t.boolean "auto_categorized", default: false
    t.bigint "category_id"
    t.datetime "created_at", null: false
    t.bigint "credit_card_id", null: false
    t.integer "installments", default: 1
    t.text "notes"
    t.date "purchased_at", null: false
    t.string "title", null: false
    t.decimal "total_amount", precision: 15, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_credit_card_purchases_on_category_id"
    t.index ["credit_card_id", "purchased_at"], name: "index_credit_card_purchases_on_credit_card_id_and_purchased_at"
    t.index ["credit_card_id"], name: "index_credit_card_purchases_on_credit_card_id"
  end

  create_table "credit_cards", force: :cascade do |t|
    t.boolean "active", default: true
    t.bigint "bank_account_id", null: false
    t.string "brand"
    t.integer "closing_day", null: false
    t.string "color"
    t.datetime "created_at", null: false
    t.decimal "credit_limit", precision: 15, scale: 2
    t.integer "due_day", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["bank_account_id"], name: "index_credit_cards_on_bank_account_id"
    t.index ["user_id"], name: "index_credit_cards_on_user_id"
  end

  create_table "financial_insights", force: :cascade do |t|
    t.string "ai_provider", default: "groq"
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.string "model_used"
    t.string "period", null: false
    t.jsonb "raw_metrics", default: {}
    t.string "status", default: "completed"
    t.text "summary"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "created_at"], name: "index_financial_insights_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_financial_insights_on_user_id"
  end

  create_table "recurrences", force: :cascade do |t|
    t.boolean "active", default: true
    t.decimal "amount", precision: 15, scale: 2, null: false
    t.bigint "bank_account_id", null: false
    t.bigint "category_id"
    t.datetime "created_at", null: false
    t.date "end_date"
    t.string "frequency", null: false
    t.integer "interval", default: 1
    t.integer "occurrences_generated", default: 0
    t.string "payment_method"
    t.date "start_date", null: false
    t.string "title", null: false
    t.integer "total_occurrences"
    t.string "transaction_type", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["bank_account_id"], name: "index_recurrences_on_bank_account_id"
    t.index ["category_id"], name: "index_recurrences_on_category_id"
    t.index ["user_id", "active", "start_date"], name: "index_recurrences_on_user_id_and_active_and_start_date"
    t.index ["user_id"], name: "index_recurrences_on_user_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.decimal "amount", precision: 15, scale: 2, null: false
    t.boolean "auto_categorized", default: false
    t.bigint "bank_account_id", null: false
    t.bigint "category_id"
    t.datetime "created_at", null: false
    t.bigint "credit_card_id"
    t.bigint "destination_bank_account_id"
    t.date "due_date", null: false
    t.string "idempotency_key"
    t.text "notes"
    t.boolean "paid", default: false
    t.date "paid_at"
    t.string "payment_method"
    t.bigint "recurrence_id"
    t.integer "recurrence_index"
    t.bigint "related_transfer_id"
    t.string "title", null: false
    t.string "transaction_type", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["bank_account_id", "paid"], name: "index_transactions_on_bank_account_id_and_paid"
    t.index ["bank_account_id"], name: "index_transactions_on_bank_account_id"
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["credit_card_id"], name: "index_transactions_on_credit_card_id"
    t.index ["destination_bank_account_id"], name: "index_transactions_on_destination_bank_account_id"
    t.index ["recurrence_id"], name: "index_transactions_on_recurrence_id"
    t.index ["related_transfer_id"], name: "index_transactions_on_related_transfer_id"
    t.index ["user_id", "due_date"], name: "index_transactions_on_user_id_and_due_date"
    t.index ["user_id", "idempotency_key"], name: "index_transactions_on_user_id_and_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["user_id"], name: "index_transactions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "custom_gemini_api_key"
    t.string "custom_groq_api_key"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "gemini_model"
    t.string "groq_model"
    t.string "name"
    t.string "preferred_ai_provider", default: "groq"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "bank_accounts", "users"
  add_foreign_key "categories", "categories", column: "parent_id"
  add_foreign_key "categories", "users"
  add_foreign_key "category_keywords", "categories"
  add_foreign_key "credit_card_expenses", "credit_card_invoices", column: "invoice_id"
  add_foreign_key "credit_card_expenses", "credit_card_purchases"
  add_foreign_key "credit_card_invoices", "credit_cards"
  add_foreign_key "credit_card_invoices", "transactions"
  add_foreign_key "credit_card_purchases", "categories"
  add_foreign_key "credit_card_purchases", "credit_cards"
  add_foreign_key "credit_cards", "bank_accounts"
  add_foreign_key "credit_cards", "users"
  add_foreign_key "financial_insights", "users"
  add_foreign_key "recurrences", "bank_accounts"
  add_foreign_key "recurrences", "categories"
  add_foreign_key "recurrences", "users"
  add_foreign_key "transactions", "bank_accounts"
  add_foreign_key "transactions", "bank_accounts", column: "destination_bank_account_id"
  add_foreign_key "transactions", "categories"
  add_foreign_key "transactions", "credit_cards"
  add_foreign_key "transactions", "recurrences"
  add_foreign_key "transactions", "transactions", column: "related_transfer_id", on_delete: :nullify
  add_foreign_key "transactions", "users"
end
