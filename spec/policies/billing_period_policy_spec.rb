# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BillingPeriodPolicy, type: :model do
  let(:admin) do
    User.create!(username: 'admin-user', email: 'admin@example.com', first_name: 'Admin', last_name: 'User',
                 role: :admin)
  end
  let(:facilities_user) do
    User.create!(username: 'facilities-user', email: 'facilities@example.com', first_name: 'Facilities',
                 last_name: 'User', role: :facilities)
  end
  let(:regular_user) do
    User.create!(username: 'regular-user', email: 'user@example.com', first_name: 'Regular', last_name: 'User')
  end
  let(:billing_period) { BillingPeriod.create!(period_start: Date.new(2026, 1, 1), period_end: Date.new(2026, 1, 31)) }

  describe '#show? and #reset?' do
    it 'permits admin' do
      expect(described_class.new(admin, billing_period).show?).to eql(true)
      expect(described_class.new(admin, billing_period).reset?).to eql(true)
    end

    it 'permits facilities' do
      expect(described_class.new(facilities_user, billing_period).show?).to eql(true)
      expect(described_class.new(facilities_user, billing_period).reset?).to eql(true)
    end

    it 'forbids a regular user' do
      expect(described_class.new(regular_user, billing_period).show?).to eql(false)
      expect(described_class.new(regular_user, billing_period).reset?).to eql(false)
    end
  end

  describe 'Scope' do
    it 'returns all billing periods for facilities' do
      billing_period
      expect(described_class::Scope.new(facilities_user, BillingPeriod).resolve).to include(billing_period)
    end

    it 'returns no billing periods for a regular user' do
      billing_period
      expect(described_class::Scope.new(regular_user, BillingPeriod).resolve).to be_empty
    end
  end
end
