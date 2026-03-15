# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvoicePolicy, type: :model do
  subject { described_class.new(user, invoice) }

  let(:invoice_owner) do
    User.create!(
      username: 'invoice-owner',
      email: 'invoice-owner@example.com',
      first_name: 'Invoice',
      last_name: 'Owner'
    )
  end

  let(:invoice) do
    Invoice.create!(
      user: invoice_owner,
      cashctrl_person_id: 123,
      period_start: Date.new(2025, 1, 1),
      period_end: Date.new(2025, 1, 31)
    )
  end

  describe 'for an admin user' do
    let(:user) do
      User.create!(
        username: 'admin-user',
        email: 'admin@example.com',
        first_name: 'Admin',
        last_name: 'User',
        role: :admin
      )
    end

    it 'permits index' do
      expect(subject.index?).to be true
    end

    it 'permits show' do
      expect(subject.show?).to be true
    end

    it 'permits send_email' do
      expect(subject.send_email?).to be true
    end

    it 'permits download_pdf' do
      expect(subject.download_pdf?).to be true
    end

    it 'permits refresh_status' do
      expect(subject.refresh_status?).to be true
    end
  end

  describe 'for a regular user' do
    let(:user) do
      User.create!(
        username: 'regular-user',
        email: 'user@example.com',
        first_name: 'Regular',
        last_name: 'User'
      )
    end

    it 'forbids index' do
      expect(subject.index?).to be false
    end

    it 'forbids show' do
      expect(subject.show?).to be false
    end

    it 'forbids send_email' do
      expect(subject.send_email?).to be false
    end

    it 'forbids download_pdf' do
      expect(subject.download_pdf?).to be false
    end

    it 'forbids refresh_status' do
      expect(subject.refresh_status?).to be false
    end
  end

  describe 'Scope' do
    let!(:invoice1) do
      Invoice.create!(
        user: invoice_owner,
        cashctrl_person_id: 123,
        period_start: Date.new(2025, 1, 1),
        period_end: Date.new(2025, 1, 31)
      )
    end

    let!(:invoice2) do
      Invoice.create!(
        user: invoice_owner,
        cashctrl_person_id: 123,
        period_start: Date.new(2025, 2, 1),
        period_end: Date.new(2025, 2, 28)
      )
    end

    describe 'for an admin user' do
      let(:user) do
        User.create!(
          username: 'admin-user',
          email: 'admin@example.com',
          first_name: 'Admin',
          last_name: 'User',
          role: :admin
        )
      end

      it 'returns all invoices' do
        scope = described_class::Scope.new(user, Invoice).resolve
        expect(scope).to include(invoice1, invoice2)
      end
    end

    describe 'for a regular user' do
      let(:user) do
        User.create!(
          username: 'regular-user',
          email: 'user@example.com',
          first_name: 'Regular',
          last_name: 'User'
        )
      end

      it 'returns no invoices' do
        scope = described_class::Scope.new(user, Invoice).resolve
        expect(scope).to be_empty
      end
    end
  end
end
