# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JournalEntryPolicy, type: :model do
  subject { described_class.new(user, journal_entry) }

  let(:entry_owner) do
    User.create!(
      username: 'entry-owner',
      email: 'entry-owner@example.com',
      first_name: 'Entry',
      last_name: 'Owner',
      billing_type: :prepaid
    )
  end

  let(:journal_entry) do
    JournalEntry.create!(
      user: entry_owner,
      period_start: Date.new(2025, 1, 1),
      period_end: Date.new(2025, 1, 31),
      total_amount: 100.0,
      reservation_count: 5
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
  end

  describe 'Scope' do
    let!(:journal_entry1) do
      JournalEntry.create!(
        user: entry_owner,
        period_start: Date.new(2025, 1, 1),
        period_end: Date.new(2025, 1, 31),
        total_amount: 100.0,
        reservation_count: 5
      )
    end

    let!(:journal_entry2) do
      JournalEntry.create!(
        user: entry_owner,
        period_start: Date.new(2025, 2, 1),
        period_end: Date.new(2025, 2, 28),
        total_amount: 150.0,
        reservation_count: 8
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

      it 'returns all journal entries' do
        scope = described_class::Scope.new(user, JournalEntry).resolve
        expect(scope).to include(journal_entry1, journal_entry2)
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

      it 'returns no journal entries' do
        scope = described_class::Scope.new(user, JournalEntry).resolve
        expect(scope).to be_empty
      end
    end
  end
end
