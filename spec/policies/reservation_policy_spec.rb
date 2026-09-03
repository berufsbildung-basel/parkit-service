# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReservationPolicy, type: :model do
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
  let(:parking_spot) { ParkingSpot.create!(number: 40) }

  let(:own_reservation) { Reservation.new(user: regular_user) }
  let(:others_reservation) { Reservation.new(user: other_user) }
  let(:guest_reservation) do
    GuestReservation.new(parking_spot:, guest_name: 'Guest', guest_license_plate: 'G1')
  end

  describe '#edit?' do
    it 'permits admin on another user\'s reservation' do
      expect(described_class.new(admin, others_reservation).edit?).to eql(true)
    end

    it 'permits facilities on another user\'s reservation' do
      expect(described_class.new(facilities_user, others_reservation).edit?).to eql(true)
    end

    it 'permits facilities on a guest reservation' do
      expect(described_class.new(facilities_user, guest_reservation).edit?).to eql(true)
    end

    it 'permits a regular user on their own reservation' do
      expect(described_class.new(regular_user, own_reservation).edit?).to eql(true)
    end

    it 'forbids a regular user on another user\'s reservation' do
      expect(described_class.new(regular_user, others_reservation).edit?).to eql(false)
    end

    it 'forbids a regular user on a guest reservation' do
      expect(described_class.new(regular_user, guest_reservation).edit?).to eql(false)
    end
  end

  describe '#new_guest?' do
    it 'permits admin and facilities' do
      expect(described_class.new(admin, guest_reservation).new_guest?).to eql(true)
      expect(described_class.new(facilities_user, guest_reservation).new_guest?).to eql(true)
    end

    it 'forbids a regular user' do
      expect(described_class.new(regular_user, guest_reservation).new_guest?).to eql(false)
    end
  end

  describe 'Pundit policy resolution for GuestReservation' do
    it 'resolves to ReservationPolicy without raising' do
      expect(Pundit.policy!(admin, guest_reservation)).to be_a(described_class)
    end
  end

  describe 'Scope' do
    let!(:vehicle) do
      Vehicle.create!(license_plate_number: 'ZH 1', make: 'VW', model: 'Golf', user: regular_user)
    end
    let!(:member_reservation) do
      Reservation.create!(parking_spot:, vehicle:, user: regular_user, date: Date.today)
    end
    let!(:persisted_guest_reservation) do
      second_spot = ParkingSpot.create!(number: 41)
      GuestReservation.create!(parking_spot: second_spot, guest_name: 'Guest', guest_license_plate: 'G1',
                                date: Date.today)
    end

    describe 'for facilities' do
      it 'returns every reservation, including guest ones' do
        scope = described_class::Scope.new(facilities_user, Reservation).resolve
        expect(scope).to include(member_reservation, persisted_guest_reservation)
      end
    end

    describe 'for admin' do
      it 'returns every reservation, including guest ones' do
        scope = described_class::Scope.new(admin, Reservation).resolve
        expect(scope).to include(member_reservation, persisted_guest_reservation)
      end
    end

    describe 'for a regular user' do
      it 'returns only their own reservations, never guest ones' do
        scope = described_class::Scope.new(regular_user, Reservation).resolve
        expect(scope).to include(member_reservation)
        expect(scope).not_to include(persisted_guest_reservation)
      end
    end
  end
end
