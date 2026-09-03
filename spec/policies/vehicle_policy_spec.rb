# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VehiclePolicy, type: :model do
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
  let(:own_vehicle) do
    Vehicle.create!(license_plate_number: 'ZH 1', make: 'VW', model: 'Golf', user: regular_user)
  end
  let(:others_vehicle) do
    Vehicle.create!(license_plate_number: 'ZH 2', make: 'VW', model: 'Golf', user: other_user)
  end

  describe '#edit? (and update?/show?, which delegate to it)' do
    it 'permits admin on another user\'s vehicle' do
      expect(described_class.new(admin, others_vehicle).edit?).to eql(true)
    end

    it 'permits facilities on another user\'s vehicle' do
      expect(described_class.new(facilities_user, others_vehicle).edit?).to eql(true)
    end

    it 'permits a regular user on their own vehicle' do
      expect(described_class.new(regular_user, own_vehicle).edit?).to eql(true)
    end

    it 'forbids a regular user on another user\'s vehicle' do
      expect(described_class.new(regular_user, others_vehicle).edit?).to eql(false)
    end
  end

  describe '#destroy?' do
    it 'permits facilities on another user\'s vehicle regardless of reservations' do
      others_vehicle.reservations.build(
        parking_spot: ParkingSpot.create!(number: 41), user: other_user, date: Date.tomorrow
      )
      expect(described_class.new(facilities_user, others_vehicle).destroy?).to eql(true)
    end

    it 'forbids a regular user on their own vehicle when it has reservations' do
      own_vehicle.reservations.build(
        parking_spot: ParkingSpot.create!(number: 42), user: regular_user, date: Date.tomorrow
      )
      expect(described_class.new(regular_user, own_vehicle).destroy?).to eql(false)
    end
  end

  describe 'Scope' do
    it 'returns all vehicles for facilities' do
      others_vehicle
      expect(described_class::Scope.new(facilities_user, Vehicle).resolve).to include(others_vehicle)
    end

    it 'returns only own vehicles for a regular user' do
      own_vehicle
      others_vehicle
      scope = described_class::Scope.new(regular_user, Vehicle).resolve
      expect(scope).to include(own_vehicle)
      expect(scope).not_to include(others_vehicle)
    end
  end
end
