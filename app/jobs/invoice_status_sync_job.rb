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
    order = client.get_invoice(invoice.cashctrl_invoice_id)['data']
    status_id = order['statusId']

    case status_id
    when CashctrlClient.status_ids[:paid]
      invoice.update!(
        status: :paid,
        cashctrl_status: status_id.to_s,
        paid_at: payment_date(client, invoice, order)
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

  # CashCtrl orders carry no payment date. Use the latest non-GENERATED book entry
  # (GENERATED ones book the invoice items), then dateLastBooked, then today.
  def payment_date(client, invoice, order)
    payments = client.list_invoice_book_entries(invoice.cashctrl_invoice_id)
                     .reject { |entry| entry['type'] == 'GENERATED' }

    payments.filter_map { |entry| parse_date(entry['date']) }.max ||
      parse_date(order['dateLastBooked']) ||
      Date.current
  end

  def parse_date(date_string)
    Date.parse(date_string) if date_string.present?
  end
end
