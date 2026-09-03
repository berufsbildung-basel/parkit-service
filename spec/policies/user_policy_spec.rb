# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserPolicy, type: :model do
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
  let(:other_user) do
    User.create!(username: 'other-user', email: 'other@example.com', first_name: 'Other', last_name: 'User')
  end

  describe '#show?' do
    it 'permits admin on another user' do
      expect(described_class.new(admin, other_user).show?).to eql(true)
    end

    it 'permits facilities on another user' do
      expect(described_class.new(facilities_user, other_user).show?).to eql(true)
    end

    it 'permits a regular user on themselves' do
      expect(described_class.new(regular_user, regular_user).show?).to eql(true)
    end

    it 'forbids a regular user on another user' do
      expect(described_class.new(regular_user, other_user).show?).to eql(false)
    end
  end

  describe '#edit? (and update?/create?, which delegate to it)' do
    it 'permits admin on another user' do
      expect(described_class.new(admin, other_user).edit?).to eql(true)
    end

    it 'forbids facilities on another user' do
      expect(described_class.new(facilities_user, other_user).edit?).to eql(false)
    end

    it 'permits facilities on themselves' do
      expect(described_class.new(facilities_user, facilities_user).edit?).to eql(true)
    end

    it 'forbids a regular user on another user' do
      expect(described_class.new(regular_user, other_user).edit?).to eql(false)
    end
  end

  describe '#create_topup_invoice?' do
    it 'permits admin' do
      expect(described_class.new(admin, other_user).create_topup_invoice?).to eql(true)
    end

    it 'permits facilities' do
      expect(described_class.new(facilities_user, other_user).create_topup_invoice?).to eql(true)
    end

    it 'forbids a regular user' do
      expect(described_class.new(regular_user, other_user).create_topup_invoice?).to eql(false)
    end
  end

  describe 'Scope' do
    it 'returns all users for admin' do
      other_user
      expect(described_class::Scope.new(admin, User).resolve).to include(other_user)
    end

    it 'returns all users for facilities' do
      other_user
      expect(described_class::Scope.new(facilities_user, User).resolve).to include(other_user)
    end

    it 'returns no users for a regular user' do
      other_user
      expect(described_class::Scope.new(regular_user, User).resolve).to be_empty
    end
  end
end
