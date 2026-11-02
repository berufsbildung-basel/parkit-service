# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Invoices', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) do
    User.create!(
      username: 'admin-user',
      email: 'admin@example.com',
      first_name: 'Admin',
      last_name: 'User',
      role: :admin
    )
  end

  before do
    sign_in admin
    allow_any_instance_of(CashctrlClient).to receive(:ping).and_return(true)
  end

  describe 'GET /admin/invoices' do
    let(:user_a) do
      User.create!(
        username: 'alice',
        email: 'alice@example.com',
        first_name: 'Alice',
        last_name: 'Test'
      )
    end
    let(:user_b) do
      User.create!(
        username: 'bob',
        email: 'bob@example.com',
        first_name: 'Bob',
        last_name: 'Test'
      )
    end

    let!(:jan_invoice) do
      Invoice.create!(
        user: user_a,
        period_start: Date.new(2026, 1, 1),
        period_end: Date.new(2026, 1, 31),
        status: :sent,
        cashctrl_person_id: 1
      )
    end
    let!(:feb_invoice) do
      Invoice.create!(
        user: user_b,
        period_start: Date.new(2026, 2, 1),
        period_end: Date.new(2026, 2, 28),
        status: :paid,
        cashctrl_person_id: 2
      )
    end

    it 'returns all invoices without filters' do
      get admin_invoices_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include('alice@example.com')
      expect(response.body).to include('bob@example.com')
    end

    it 'filters by period' do
      get admin_invoices_path, params: { period: '2026-01-01' }
      expect(response.body).to include('alice@example.com')
      expect(response.body).not_to include('bob@example.com')
    end

    it 'filters by status' do
      get admin_invoices_path, params: { status: 'paid' }
      expect(response.body).to include('bob@example.com')
      expect(response.body).not_to include('alice@example.com')
    end

    it 'filters by user search' do
      get admin_invoices_path, params: { q: 'alice' }
      expect(response.body).to include('alice@example.com')
      expect(response.body).not_to include('bob@example.com')
    end

    it 'combines filters' do
      get admin_invoices_path, params: { status: 'sent', q: 'alice' }
      expect(response.body).to include('alice@example.com')
      expect(response.body).not_to include('bob@example.com')
    end
  end

  describe 'status refresh' do
    let(:api) { 'https://test-org.cashctrl.com/api/v1' }
    let(:order_read) { JSON.parse(file_fixture('cashctrl/order_read.json').read) }
    let(:book_entries) { JSON.parse(file_fixture('cashctrl/order_bookentry_list.json').read)['data'] }
    let(:user) do
      User.create!(username: 'carol', email: 'carol@example.com', first_name: 'Carol', last_name: 'Test')
    end

    def create_sent_invoice(cashctrl_id, month)
      Invoice.create!(
        user:,
        cashctrl_person_id: 1,
        cashctrl_invoice_id: cashctrl_id,
        period_start: Date.new(2025, month, 1),
        period_end: Date.new(2025, month, 1).end_of_month,
        status: :sent
      )
    end

    def stub_order_read(id, **fields)
      data = order_read['data'].merge('id' => id).merge(fields.transform_keys(&:to_s))
      stub_request(:get, "#{api}/order/read.json")
        .with(query: { id: id.to_s })
        .to_return(status: 200, body: order_read.merge('data' => data).to_json)
    end

    def stub_order_read_failure(id)
      stub_request(:get, "#{api}/order/read.json")
        .with(query: { id: id.to_s })
        .to_return(status: 200, body: { success: false }.to_json)
    end

    def stub_book_entries(id)
      stub_request(:get, "#{api}/order/bookentry/list.json")
        .with(query: { id: id.to_s })
        .to_return(status: 200, body: { total: book_entries.size, data: book_entries }.to_json)
    end

    describe 'POST /admin/invoices/refresh_all' do
      let!(:paid_in_cashctrl) { create_sent_invoice(2001, 1) }
      let!(:missing_in_cashctrl) { create_sent_invoice(2002, 2) }
      let!(:cancelled_in_cashctrl) { create_sent_invoice(2003, 3) }

      before do
        stub_order_read(2001, statusId: CashctrlClient.status_ids[:paid])
        stub_book_entries(2001)
        stub_order_read_failure(2002)
        stub_order_read(2003, statusId: CashctrlClient.status_ids[:cancelled])
      end

      it 'reads the status from the order envelope and records the payment date' do
        post refresh_all_admin_invoices_path

        paid_in_cashctrl.reload
        expect(paid_in_cashctrl.status).to eq('paid')
        expect(paid_in_cashctrl.cashctrl_status).to eq(CashctrlClient.status_ids[:paid].to_s)
        expect(paid_in_cashctrl.paid_at.to_date).to eq(Date.new(2025, 2, 14))
      end

      it 'keeps syncing past an invoice CashCtrl rejects and reports it' do
        post refresh_all_admin_invoices_path

        expect(response).to redirect_to(admin_invoices_path)
        expect(cancelled_in_cashctrl.reload.status).to eq('cancelled')
        expect(missing_in_cashctrl.reload.status).to eq('sent')
        expect(flash[:alert]).to include("##{missing_in_cashctrl.id}")
      end
    end

    describe 'POST /admin/invoices/:id/refresh_status' do
      let!(:invoice) { create_sent_invoice(2002, 2) }

      it 'redirects with an alert instead of failing when CashCtrl rejects the read' do
        stub_order_read_failure(2002)

        post refresh_status_admin_invoice_path(invoice)

        expect(response).to redirect_to(admin_invoices_path)
        expect(flash[:alert]).to include("##{invoice.id}")
      end
    end
  end
end
