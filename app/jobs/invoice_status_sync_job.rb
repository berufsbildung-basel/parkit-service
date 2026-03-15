# frozen_string_literal: true

# Syncs invoice status from CashCtrl for sent invoices
class InvoiceStatusSyncJob < ApplicationJob
  queue_as :default

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
    when CashctrlClient.status_ids[:paid]
      invoice.update!(
        status: :paid,
        cashctrl_status: status_id.to_s,
        paid_at: parse_date(response['datePayment'])
      )
    when CashctrlClient.status_ids[:cancelled]
      invoice.update!(
        status: :cancelled,
        cashctrl_status: status_id.to_s
      )
    end
  rescue StandardError => e
    Rails.logger.error("Failed to sync invoice #{invoice.id}: #{e.message}")
  end

  def parse_date(date_string)
    Date.parse(date_string) if date_string.present?
  end
end
