# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvoiceStatusSyncJob, type: :job do
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

  let(:client) { instance_double(CashctrlClient) }

  before do
    allow(CashctrlClient).to receive(:new).and_return(client)
  end

  describe '#perform' do
    context 'when invoice is paid in CashCtrl' do
      before do
        allow(client).to receive(:get_invoice).with(1001).and_return({
                                                                       'statusId' => CashctrlClient::STATUS_IDS[:paid],
                                                                       'datePayment' => '2025-01-15'
                                                                     })
      end

      it 'updates the invoice status to paid' do
        described_class.new.perform

        sent_invoice.reload
        expect(sent_invoice.status).to eq('paid')
        expect(sent_invoice.paid_at.to_date).to eq(Date.parse('2025-01-15'))
      end

      it 'does not update draft invoices' do
        described_class.new.perform

        draft_invoice.reload
        expect(draft_invoice.status).to eq('draft')
      end

      it 'does not re-check already paid invoices' do
        described_class.new.perform

        expect(client).not_to have_received(:get_invoice).with(1002)
      end
    end

    context 'when invoice is still sent in CashCtrl' do
      before do
        allow(client).to receive(:get_invoice).with(1001).and_return({
                                                                       'statusId' => CashctrlClient::STATUS_IDS[:sent]
                                                                     })
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
        allow(client).to receive(:get_invoice).with(1001).and_return({
                                                                       'statusId' => CashctrlClient::STATUS_IDS[:cancelled]
                                                                     })
      end

      it 'updates the invoice status to cancelled' do
        described_class.new.perform

        sent_invoice.reload
        expect(sent_invoice.status).to eq('cancelled')
      end
    end
  end
end
