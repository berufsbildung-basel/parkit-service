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
end
