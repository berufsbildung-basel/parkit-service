# frozen_string_literal: true

# config/initializers/cashctrl.rb
Rails.application.config.cashctrl = {
  org: ENV.fetch('CASHCTRL_ORG', nil),
  api_key: ENV.fetch('CASHCTRL_API_KEY', nil),
  billing_start_date: ENV.fetch('BILLING_START_DATE', nil)&.to_date,
  invoice_category_id: ENV.fetch('CASHCTRL_INVOICE_CATEGORY_ID', nil)&.to_i,
  sales_account_id: ENV.fetch('CASHCTRL_SALES_ACCOUNT_ID', nil)&.to_i,
  tax_id: ENV.fetch('CASHCTRL_TAX_ID', nil)&.to_i,

  # Custom field ID for billing period (fieldId, not the numeric ID)
  billing_period_field_id: ENV.fetch('CASHCTRL_BILLING_PERIOD_FIELD_ID', nil),

  # Invoice category status IDs (differ per CashCtrl tenant)
  status_id_draft: ENV.fetch('CASHCTRL_STATUS_ID_DRAFT', nil)&.to_i,
  status_id_sent: ENV.fetch('CASHCTRL_STATUS_ID_SENT', nil)&.to_i,
  status_id_paid: ENV.fetch('CASHCTRL_STATUS_ID_PAID', nil)&.to_i,
  status_id_cancelled: ENV.fetch('CASHCTRL_STATUS_ID_CANCELLED', nil)&.to_i,

  # Artikel numbers for parking reservations (e.g., "PARK-CAR-FD-WD")
  artikel: {
    car_halfday_weekday: ENV.fetch('CASHCTRL_ARTIKEL_CAR_HALFDAY_WEEKDAY', nil),
    car_halfday_weekend: ENV.fetch('CASHCTRL_ARTIKEL_CAR_HALFDAY_WEEKEND', nil),
    car_fullday_weekday: ENV.fetch('CASHCTRL_ARTIKEL_CAR_FULLDAY_WEEKDAY', nil),
    car_fullday_weekend: ENV.fetch('CASHCTRL_ARTIKEL_CAR_FULLDAY_WEEKEND', nil),
    motorcycle_halfday_weekday: ENV.fetch('CASHCTRL_ARTIKEL_MOTORCYCLE_HALFDAY_WEEKDAY', nil),
    motorcycle_halfday_weekend: ENV.fetch('CASHCTRL_ARTIKEL_MOTORCYCLE_HALFDAY_WEEKEND', nil),
    motorcycle_fullday_weekday: ENV.fetch('CASHCTRL_ARTIKEL_MOTORCYCLE_FULLDAY_WEEKDAY', nil),
    motorcycle_fullday_weekend: ENV.fetch('CASHCTRL_ARTIKEL_MOTORCYCLE_FULLDAY_WEEKEND', nil)
  }
}
