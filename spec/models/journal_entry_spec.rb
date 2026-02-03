# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JournalEntry, type: :model do
  let(:user) do
    User.create!(
      username: 'prepaid-user',
      email: 'prepaid@example.com',
      first_name: 'Prepaid',
      last_name: 'User',
      billing_type: :prepaid,
      cashctrl_private_account_id: 12_345
    )
  end

  describe 'validations' do
    it 'requires user' do
      entry = JournalEntry.new(
        period_start: Date.new(2025, 1, 1),
        period_end: Date.new(2025, 1, 31)
      )
      expect(entry).not_to be_valid
      expect(entry.errors[:user]).to include('must exist')
    end

    it 'enforces unique user/period_start combination' do
      JournalEntry.create!(
        user: user,
        period_start: Date.new(2025, 1, 1),
        period_end: Date.new(2025, 1, 31),
        total_amount: 100,
        reservation_count: 5
      )

      duplicate = JournalEntry.new(
        user: user,
        period_start: Date.new(2025, 1, 1),
        period_end: Date.new(2025, 1, 31)
      )
      expect(duplicate).not_to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to user' do
      entry = JournalEntry.new
      expect(entry).to respond_to(:user)
    end
  end

  describe 'scopes' do
    let!(:entry) do
      JournalEntry.create!(
        user: user,
        period_start: Date.new(2025, 1, 1),
        period_end: Date.new(2025, 1, 31),
        total_amount: 100,
        reservation_count: 5
      )
    end

    it 'filters by period' do
      expect(JournalEntry.for_period(Date.new(2025, 1, 1))).to include(entry)
      expect(JournalEntry.for_period(Date.new(2025, 2, 1))).not_to include(entry)
    end
  end
end
