# frozen_string_literal: true

require "test_helper"

class ReportsControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  setup do
    @user = users(:one)
    sign_in @user
  end

  test "should get index with html format" do
    get :index
    assert_response :success
    assert_not_nil assigns(:report_data)
    assert_equal "6_months", assigns(:period)
  end

  test "should get index with custom period" do
    get :index, params: { period: "12_months" }
    assert_response :success
    assert_equal "12_months", assigns(:period)
  end

  test "should export csv format" do
    get :index, params: { period: "6_months", format: :csv }
    assert_response :success
    assert_equal "text/csv; charset=utf-8", response.content_type
    assert_includes response.body, "RELATÓRIO FINANCEIRO CONSOLIDADO"
  end

  test "index without authentication should redirect to login" do
    sign_out @user
    get :index
    assert_redirected_to new_user_session_path
  end
end
