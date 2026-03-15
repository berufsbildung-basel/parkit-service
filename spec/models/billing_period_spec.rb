# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BillingPeriod, type: :model do
  let(:admin) { User.create!(username: 'admin_user', email: 'admin@example.com', first_name: 'Admin', last_name: 'User', role: :admin) }

  describe 'validations' do
    it 'requires period_start' do
      bp = BillingPeriod.new(period_end: Date.new(2026, 1, 31))
      expect(bp).not_to be_valid
      expect(bp.errors[:period_start]).to be_present
    end

    it 'requires period_end' do
      bp = BillingPeriod.new(period_start: Date.new(2026, 1, 1))
      expect(bp).not_to be_valid
      expect(bp.errors[:period_end]).to be_present
    end

    it 'enforces unique period_start' do
      BillingPeriod.create!(period_start: Date.new(2026, 1, 1), period_end: Date.new(2026, 1, 31))
      duplicate = BillingPeriod.new(period_start: Date.new(2026, 1, 1), period_end: Date.new(2026, 1, 31))
      expect(duplicate).not_to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to executed_by user' do
      bp = BillingPeriod.create!(
        period_start: Date.new(2026, 1, 1),
        period_end: Date.new(2026, 1, 31),
        executed_by: admin
      )
      expect(bp.executed_by).to eq(admin)
    end
  end

  describe 'enums' do
    it 'has correct status values' do
      expect(BillingPeriod.statuses).to eq(
        'unbilled' => 0, 'in_progress' => 1, 'completed' => 2, 'partially_failed' => 3
      )
    end
  end

  describe 'scopes' do
    it 'returns completed billing periods' do
      completed = BillingPeriod.create!(period_start: Date.new(2026, 1, 1), period_end: Date.new(2026, 1, 31), status: :completed)
      BillingPeriod.create!(period_start: Date.new(2026, 2, 1), period_end: Date.new(2026, 2, 28), status: :unbilled)

      expect(BillingPeriod.completed).to contain_exactly(completed)
    end
  end
end
