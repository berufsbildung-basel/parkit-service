# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ParkingSpotPolicy, type: :model do
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
  let(:parking_spot) { ParkingSpot.create!(number: 43) }

  describe '#edit? (and update?/destroy?/new?/create?/show?/archive?/unarchive?, which delegate to it)' do
    it 'permits admin' do
      expect(described_class.new(admin, parking_spot).edit?).to eql(true)
    end

    it 'permits facilities' do
      expect(described_class.new(facilities_user, parking_spot).edit?).to eql(true)
    end

    it 'forbids a regular user' do
      expect(described_class.new(regular_user, parking_spot).edit?).to eql(false)
    end
  end

  describe 'Scope' do
    it 'returns all parking spots for facilities' do
      parking_spot
      expect(described_class::Scope.new(facilities_user, ParkingSpot).resolve).to include(parking_spot)
    end

    it 'returns no parking spots for a regular user' do
      parking_spot
      expect(described_class::Scope.new(regular_user, ParkingSpot).resolve).to be_empty
    end
  end
end
