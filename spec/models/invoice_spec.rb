# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Invoice, type: :model do
  let(:user) do
    User.create!(
      username: 'test-user',
      email: 'test@example.com',
      first_name: 'Test',
      last_name: 'User'
    )
  end

  describe 'validations' do
    it 'requires user' do
      invoice = Invoice.new(
        cashctrl_person_id: 123,
        period_start: Date.new(2025, 1, 1),
        period_end: Date.new(2025, 1, 31)
      )
      expect(invoice).not_to be_valid
      expect(invoice.errors[:user]).to include('must exist')
    end

    it 'requires cashctrl_person_id' do
      invoice = Invoice.new(
        user: user,
        period_start: Date.new(2025, 1, 1),
        period_end: Date.new(2025, 1, 31)
      )
      expect(invoice).not_to be_valid
      expect(invoice.errors[:cashctrl_person_id]).to include("can't be blank")
    end

    it 'enforces unique user/period_start combination' do
      Invoice.create!(
        user: user,
        cashctrl_person_id: 123,
        period_start: Date.new(2025, 1, 1),
        period_end: Date.new(2025, 1, 31)
      )

      duplicate = Invoice.new(
        user: user,
        cashctrl_person_id: 123,
        period_start: Date.new(2025, 1, 1),
        period_end: Date.new(2025, 1, 31)
      )
      expect(duplicate).not_to be_valid
    end
  end

  describe 'status enum' do
    it 'has expected statuses' do
      expect(Invoice.statuses.keys).to eq(%w[draft sent paid cancelled])
    end
  end

  describe 'associations' do
    it 'belongs to user' do
      invoice = Invoice.new
      expect(invoice).to respond_to(:user)
    end

    it 'has many line_items' do
      invoice = Invoice.new
      expect(invoice).to respond_to(:line_items)
    end
  end

  describe 'scopes' do
    let!(:draft_invoice) do
      Invoice.create!(user: user, cashctrl_person_id: 1, period_start: Date.new(2025, 1, 1), period_end: Date.new(2025, 1, 31), status: :draft)
    end
    let!(:paid_invoice) do
      Invoice.create!(user: user, cashctrl_person_id: 1, period_start: Date.new(2025, 2, 1), period_end: Date.new(2025, 2, 28), status: :paid)
    end

    it 'filters open invoices' do
      expect(Invoice.open).to include(draft_invoice)
      expect(Invoice.open).not_to include(paid_invoice)
    end
  end
end
