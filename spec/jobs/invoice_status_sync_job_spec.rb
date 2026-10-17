# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvoiceStatusSyncJob, type: :job do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) do
    User.create!(
      username: 'test-user',
      email: 'test@example.com',
      first_name: 'Test',
      last_name: 'User'
    )
  end

  let!(:sent_invoice) do
    Invoice.create!(
      user: user,
      cashctrl_person_id: 123,
      cashctrl_invoice_id: 1001,
      period_start: Date.new(2025, 1, 1),
      period_end: Date.new(2025, 1, 31),
      status: :sent,
      sent_at: 1.day.ago
    )
  end

  let!(:draft_invoice) do
    Invoice.create!(
      user: user,
      cashctrl_person_id: 123,
      period_start: Date.new(2025, 2, 1),
      period_end: Date.new(2025, 2, 28),
      status: :draft
    )
  end

  let!(:paid_invoice) do
    Invoice.create!(
      user: user,
      cashctrl_person_id: 123,
      cashctrl_invoice_id: 1002,
      period_start: Date.new(2024, 12, 1),
      period_end: Date.new(2024, 12, 31),
      status: :paid
    )
  end

  let(:api) { 'https://test-org.cashctrl.com/api/v1' }

  # Bodies mirror the real CashCtrl responses, envelope included: order/read.json wraps the
  # order in "data", and book entries are GENERATED (the invoice items) or MANUAL (payments).
  let(:order_read) { JSON.parse(file_fixture('cashctrl/order_read.json').read) }
  let(:book_entries) { JSON.parse(file_fixture('cashctrl/order_bookentry_list.json').read)['data'] }

  def stub_order_read(id, **fields)
    data = order_read['data'].merge('id' => id).merge(fields.transform_keys(&:to_s))
    stub_request(:get, "#{api}/order/read.json")
      .with(query: { id: id.to_s })
      .to_return(status: 200, body: order_read.merge('data' => data).to_json)
  end

  def stub_book_entries(id, entries)
    stub_request(:get, "#{api}/order/bookentry/list.json")
      .with(query: { id: id.to_s })
      .to_return(status: 200, body: { total: entries.size, data: entries }.to_json)
  end

  describe '#perform' do
    context 'when invoice is paid in CashCtrl' do
      before do
        stub_order_read(1001, statusId: CashctrlClient.status_ids[:paid])
        stub_book_entries(1001, book_entries)
      end

      it 'updates the invoice status to paid' do
        described_class.new.perform

        sent_invoice.reload
        expect(sent_invoice.status).to eq('paid')
        expect(sent_invoice.cashctrl_status).to eq('3')
      end

      it 'sets paid_at to the date of the latest payment book entry' do
        stub_order_read(1001, statusId: CashctrlClient.status_ids[:paid], dateLastBooked: '2025-03-01 00:00:00.0')

        described_class.new.perform

        expect(sent_invoice.reload.paid_at.to_date).to eq(Date.new(2025, 2, 14))
      end

      it 'does not update draft invoices' do
        described_class.new.perform

        draft_invoice.reload
        expect(draft_invoice.status).to eq('draft')
      end

      it 'does not re-check already paid invoices' do
        described_class.new.perform

        expect(a_request(:get, "#{api}/order/read.json").with(query: { id: '1002' })).not_to have_been_made
      end
    end

    context 'when a paid invoice has no payment book entries' do
      let(:generated_only) { book_entries.select { |entry| entry['type'] == 'GENERATED' } }

      before { stub_book_entries(1001, generated_only) }

      it 'falls back to dateLastBooked for paid_at' do
        stub_order_read(1001, statusId: CashctrlClient.status_ids[:paid], dateLastBooked: '2025-02-20 00:00:00.0')

        described_class.new.perform

        sent_invoice.reload
        expect(sent_invoice.status).to eq('paid')
        expect(sent_invoice.paid_at.to_date).to eq(Date.new(2025, 2, 20))
      end

      it 'falls back to today when dateLastBooked is empty' do
        stub_order_read(1001, statusId: CashctrlClient.status_ids[:paid], dateLastBooked: nil)

        travel_to(Time.zone.local(2025, 3, 5, 10, 0)) { described_class.new.perform }

        sent_invoice.reload
        expect(sent_invoice.status).to eq('paid')
        expect(sent_invoice.paid_at.to_date).to eq(Date.new(2025, 3, 5))
      end
    end

    context 'when invoice is still sent in CashCtrl' do
      before do
        stub_order_read(1001, statusId: CashctrlClient.status_ids[:sent], open: 10, paid: 0, isClosed: false)
      end

      it 'keeps the invoice status as sent' do
        described_class.new.perform

        sent_invoice.reload
        expect(sent_invoice.status).to eq('sent')
        expect(sent_invoice.paid_at).to be_nil
      end
    end

    context 'when invoice is cancelled in CashCtrl' do
      before do
        stub_order_read(1001, statusId: CashctrlClient.status_ids[:cancelled])
      end

      it 'updates the invoice status to cancelled' do
        described_class.new.perform

        sent_invoice.reload
        expect(sent_invoice.status).to eq('cancelled')
        expect(sent_invoice.cashctrl_status).to eq('4')
      end
    end
  end
end
