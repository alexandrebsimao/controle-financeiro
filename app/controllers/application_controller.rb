class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user_bank_accounts, :current_user_categories, :current_user_credit_cards

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :email, :password, :password_confirmation])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :email, :password, :password_confirmation, :current_password])
  end

  private

  def current_user_bank_accounts
    @current_user_bank_accounts ||= current_user.bank_accounts.active.order(:name)
  end

  def current_user_categories
    @current_user_categories ||= Category.for_user(current_user).order(:name)
  end

  def current_user_credit_cards
    @current_user_credit_cards ||= current_user.credit_cards.active.order(:name)
  end
end

