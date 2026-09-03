# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GuestReservation, type: :model do
  let!(:car_spot) { ParkingSpot.create!(number: 30, allowed_vehicle_type: :car) }
  let!(:motorcycle_spot) { ParkingSpot.create!(number: 31, allowed_vehicle_type: :motorcycle) }

  context 'validation' do
    it 'requires a guest name' do
      reservation = GuestReservation.new(parking_spot: car_spot, date: Date.today, guest_license_plate: 'ZH 1234')

      expect(reservation.valid?).to eql(false)
      expect(reservation.errors.map(&:attribute)).to include(:guest_name)
    end

    it 'requires a guest license plate' do
      reservation = GuestReservation.new(parking_spot: car_spot, date: Date.today, guest_name: 'Jane Guest')

      expect(reservation.valid?).to eql(false)
      expect(reservation.errors.map(&:attribute)).to include(:guest_license_plate)
    end

    it 'rejects a motorcycle-only parking spot' do
      reservation = GuestReservation.new(parking_spot: motorcycle_spot, date: Date.today,
                                          guest_name: 'Jane Guest', guest_license_plate: 'ZH 1234')

      expect(reservation.valid?).to eql(false)
      expect(reservation.errors.first.attribute).to eql(:parking_spot)
    end

    it 'is valid with a name, plate, and a car parking spot, with no user or vehicle' do
      reservation = GuestReservation.new(parking_spot: car_spot, date: Date.today,
                                          guest_name: 'Jane Guest', guest_license_plate: 'ZH 1234')

      expect(reservation.valid?).to eql(true)
      expect(reservation.user).to be_nil
      expect(reservation.vehicle).to be_nil
    end
  end

  context 'pricing' do
    it 'is always free, on a weekday' do
      weekday = Date.today
      weekday += 1 until weekday.on_weekday?

      reservation = GuestReservation.create!(parking_spot: car_spot, date: weekday,
                                              guest_name: 'Jane Guest', guest_license_plate: 'ZH 1234')

      expect(reservation.price).to eq(0.0)
    end
  end

  context 'polymorphic methods' do
    it 'requires_registered_owner? is false' do
      expect(GuestReservation.new.requires_registered_owner?).to eql(false)
    end

    it 'owner_name returns the guest name' do
      expect(GuestReservation.new(guest_name: 'Jane Guest').owner_name).to eql('Jane Guest')
    end

    it 'resolves its Pundit policy_class to ReservationPolicy' do
      expect(GuestReservation.policy_class).to eq(ReservationPolicy)
    end
  end

  context 'billing visibility' do
    it 'is invisible to per-user billing, since it has no user to join through' do
      guest = GuestReservation.create!(parking_spot: car_spot, date: Date.today,
                                        guest_name: 'Jane Guest', guest_license_plate: 'ZH 1234')

      expect(User.joins(:reservations).where(reservations: { id: guest.id })).to be_empty
    end
  end
end
