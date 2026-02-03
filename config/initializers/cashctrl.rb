# frozen_string_literal: true

# config/initializers/cashctrl.rb
Rails.application.config.cashctrl = {
  org: ENV.fetch('CASHCTRL_ORG', nil),
  api_key: ENV.fetch('CASHCTRL_API_KEY', nil),
  billing_start_date: ENV.fetch('BILLING_START_DATE', nil)&.to_date,
  revenue_account_id: ENV.fetch('CASHCTRL_REVENUE_ACCOUNT_ID', nil)&.to_i
}
