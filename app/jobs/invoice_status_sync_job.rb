# frozen_string_literal: true

# Syncs invoice status from CashCtrl for sent invoices
class InvoiceStatusSyncJob < ApplicationJob
  queue_as :default

  def perform
    sync = InvoiceStatusSync.new

    Invoice.sent.where.not(cashctrl_invoice_id: nil).find_each do |invoice|
      sync.call(invoice)
    rescue StandardError => e
      Rails.logger.error("Failed to sync invoice #{invoice.id}: #{e.message}")
    end
  end
end
