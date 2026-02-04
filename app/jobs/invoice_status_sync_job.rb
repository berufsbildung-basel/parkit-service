# frozen_string_literal: true

# Syncs invoice status from CashCtrl for sent invoices
class InvoiceStatusSyncJob < ApplicationJob
  queue_as :default

  # CashCtrl status IDs
  CASHCTRL_STATUS_SENT = 1
  CASHCTRL_STATUS_PAID = 2
  CASHCTRL_STATUS_CANCELLED = 3

  def perform
    client = CashctrlClient.new

    Invoice.sent.where.not(cashctrl_invoice_id: nil).find_each do |invoice|
      sync_invoice_status(client, invoice)
    end
  end

  private

  def sync_invoice_status(client, invoice)
    response = client.get_invoice(invoice.cashctrl_invoice_id)
    status_id = response['statusId']

    case status_id
    when CASHCTRL_STATUS_PAID
      invoice.update!(
        status: :paid,
        paid_at: parse_date(response['datePayment'])
      )
    when CASHCTRL_STATUS_CANCELLED
      invoice.update!(status: :cancelled)
    end
  rescue StandardError => e
    Rails.logger.error("Failed to sync invoice #{invoice.id}: #{e.message}")
  end

  def parse_date(date_string)
    Date.parse(date_string) if date_string.present?
  end
end
