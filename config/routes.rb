require 'sidekiq/web'

Rails.application.routes.draw do
  devise_for :users
  
  get "up" => "rails/health#show", as: :rails_health_check
  match "mcp", to: "mcp#options", via: :options
  get "mcp", to: "mcp#show"
  post "mcp", to: "mcp#create"

  authenticated :user do
    root "dashboard#index", as: :authenticated_root
  end

  root "pages#home"

  # Sidekiq Web Dashboard
  Sidekiq::Web.use Rack::Auth::Basic do |username, password|
    expected_username = ENV.fetch('SIDEKIQ_USERNAME', 'admin')
    expected_password = ENV.fetch('SIDEKIQ_PASSWORD') { Rails.env.development? ? 'sidekiq' : nil }

    expected_password.present? &&
      ActiveSupport::SecurityUtils.secure_compare(username, expected_username) &&
      ActiveSupport::SecurityUtils.secure_compare(password, expected_password)
  end
  mount Sidekiq::Web => '/sidekiq'

  namespace :admin do
    resources :categories
  end

  resources :bank_accounts

  resources :transactions do
    collection do
      patch :bulk_mark_paid
      delete :bulk_destroy
    end
    member do
      patch :mark_paid
    end
  end

  resources :transaction_imports, path: "transactions/import", only: [:new, :create] do
    collection do
      post :preview
      match :cancel, via: [:get, :delete]
    end
  end

  resources :categories

  resources :financial_insights, only: %i[index show create destroy] do
    collection do
      patch :update_preference
    end
  end

  resources :reports, only: [:index]

  resource :ai_settings, path: "settings/ai", controller: "ai_settings", only: [:show, :update] do
    post :test_connection
  end
  
  resources :recurrences do
    member do
      patch :activate
      patch :deactivate
    end
  end

  resources :credit_cards do
    resources :credit_card_invoices, as: :invoices, path: 'invoices' do
      member do
        post :pay
        post :preview_csv_import
        post :import_csv
        match :clear_csv_preview, via: [:get, :delete]
      end
    end
    resources :credit_card_purchases, as: :purchases, path: 'purchases' do
      resources :credit_card_expenses, as: :expenses, path: 'expenses'
    end
  end

  namespace :dashboard do
    root "index"
    get :overview
    get :credit_cards
  end
end
