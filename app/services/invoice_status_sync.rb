# frozen_string_literal: true

# Pulls one invoice's status from CashCtrl into the local record. Only the terminal
# transitions (paid, cancelled) are applied: CashCtrl can still show an emailed invoice
# as draft, and moving it back to draft locally would make it resettable.
# Raises on CashCtrl errors; callers decide whether to log, report or abort.
class InvoiceStatusSync
  def initialize(client = CashctrlClient.new)
    @client = client
  end

  def call(invoice)
    return unless invoice.cashctrl_invoice_id

    order = @client.get_invoice(invoice.cashctrl_invoice_id)['data']
    status_id = order['statusId']

    case status_id
    when CashctrlClient.status_ids[:paid]
      invoice.update!(status: :paid, cashctrl_status: status_id.to_s, paid_at: payment_date(invoice, order))
    when CashctrlClient.status_ids[:cancelled]
      invoice.update!(status: :cancelled, cashctrl_status: status_id.to_s)
    end
  end

  private

  # CashCtrl orders carry no payment date. Use the latest non-GENERATED book entry
  # (GENERATED ones book the invoice items), then dateLastBooked, then today.
  def payment_date(invoice, order)
    payments = @client.list_invoice_book_entries(invoice.cashctrl_invoice_id)
                      .reject { |entry| entry['type'] == 'GENERATED' }

    payments.filter_map { |entry| parse_date(entry['date']) }.max ||
      parse_date(order['dateLastBooked']) ||
      Date.current
  end

  def parse_date(date_string)
    Date.parse(date_string) if date_string.present?
  end
end
