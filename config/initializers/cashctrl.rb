# frozen_string_literal: true

# config/initializers/cashctrl.rb
Rails.application.config.cashctrl = {
  org: ENV.fetch('CASHCTRL_ORG', nil),
  api_key: ENV.fetch('CASHCTRL_API_KEY', nil),
  billing_start_date: ENV.fetch('BILLING_START_DATE', nil)&.to_date,
  invoice_category_id: ENV.fetch('CASHCTRL_INVOICE_CATEGORY_ID', nil)&.to_i,

  # Artikel IDs for parking reservations
  artikel: {
    car_halfday_weekday: ENV.fetch('CASHCTRL_ARTIKEL_CAR_HALFDAY_WEEKDAY', nil)&.to_i,
    car_halfday_weekend: ENV.fetch('CASHCTRL_ARTIKEL_CAR_HALFDAY_WEEKEND', nil)&.to_i,
    car_fullday_weekday: ENV.fetch('CASHCTRL_ARTIKEL_CAR_FULLDAY_WEEKDAY', nil)&.to_i,
    car_fullday_weekend: ENV.fetch('CASHCTRL_ARTIKEL_CAR_FULLDAY_WEEKEND', nil)&.to_i,
    motorcycle_halfday_weekday: ENV.fetch('CASHCTRL_ARTIKEL_MOTORCYCLE_HALFDAY_WEEKDAY', nil)&.to_i,
    motorcycle_halfday_weekend: ENV.fetch('CASHCTRL_ARTIKEL_MOTORCYCLE_HALFDAY_WEEKEND', nil)&.to_i,
    motorcycle_fullday_weekday: ENV.fetch('CASHCTRL_ARTIKEL_MOTORCYCLE_FULLDAY_WEEKDAY', nil)&.to_i,
    motorcycle_fullday_weekend: ENV.fetch('CASHCTRL_ARTIKEL_MOTORCYCLE_FULLDAY_WEEKEND', nil)&.to_i
  }
}
