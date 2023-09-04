# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reservation, type: :model do
  parking_spot = nil
  user1 = nil
  car1 = nil

  before(:each) do
    parking_spot = ParkingSpot.create({ number: 2 })
    user1 = User.create!({
                           username: Faker::Internet.username,
                           email: Faker::Internet.email,
                           first_name: Faker::Name.first_name,
                           last_name: Faker::Name.last_name
                         })
    car1 = Vehicle.create!({
                             license_plate_number: Faker::Vehicle.unique.license_plate,
                             make: Faker::Vehicle.make,
                             model: Faker::Vehicle.model,
                             user: user1
                           })
  end

  after(:each) do
    Reservation.destroy_all
    Vehicle.destroy_all
    User.destroy_all
    ParkingSpot.destroy_all
  end

  context 'validation' do
    it 'rejects creating a reservation with no attributes set' do
      reservation = Reservation.new
      errors = reservation.errors

      expect(reservation.valid?).to eql(false)
      expect(reservation.save).to eql(false)

      expect(errors.size).to eql(8)

      expect(errors.objects[0].attribute).to eql(:parking_spot)
      expect(errors.objects[1].attribute).to eql(:vehicle)
      expect(errors.objects[2].attribute).to eql(:user)
      expect(errors.objects[3].attribute).to eql(:date)
      expect(errors.objects[6].attribute).to eql(:start_time)
      expect(errors.objects[6].attribute).to eql(:start_time)
      expect(errors.objects[7].attribute).to eql(:end_time)

      expect(errors.objects[0].full_message).to eql('Parking spot must exist')
      expect(errors.objects[1].full_message).to eql('Vehicle must exist')
      expect(errors.objects[2].full_message).to eql('User must exist')
      expect(errors.objects[3].full_message).to eql('Date is not a valid date')
      expect(errors.objects[4].full_message).to eql('Start time is not a valid date/time')
      expect(errors.objects[5].full_message).to eql('End time is not a valid date/time')
      expect(errors.objects[6].full_message).to eql('Start time is not a valid date')
      expect(errors.objects[7].full_message).to eql('End time is not a valid date')
    end

    it 'rejects creating reservation with invalid date' do
      date = 'invalid-date'
      reservation = Reservation.create({
                                         parking_spot:,
                                         vehicle: car1,
                                         user: user1,
                                         date:
                                       })
      errors = reservation.errors

      expect(errors.size).to eql(5)
      expect(errors.objects[0].full_message).to eql('Date is not a valid date')
      expect(errors.objects[1].full_message).to eql('Start time is not a valid date/time')
      expect(errors.objects[2].full_message).to eql('End time is not a valid date/time')
      expect(errors.objects[3].full_message).to eql('Start time is not a valid date')
      expect(errors.objects[4].full_message).to eql('End time is not a valid date')
    end

    it 'rejects creating a reservation with a date in the past' do
      date = Date.yesterday
      reservation = Reservation.create({
                                         parking_spot:,
                                         vehicle: car1,
                                         user: user1,
                                         date:
                                       })
      errors = reservation.errors

      expect(errors.size).to eql(1)
      expect(errors.first.full_message).to eql('Date must be on or after today\'s date')
    end
  end

  context 'creation' do

    it 'properly sets reservation times' do
      # Half-day reservation in the morning
      date = Date.today
      reservation = Reservation.create!({
                                          parking_spot:,
                                          vehicle: car1,
                                          user: user1,
                                          date:,
                                          half_day: true,
                                          am: true
                                        })

      # We accept within one second as the database persisted time has less precision than ruby time
      expect(reservation.start_time).to be_within(1.second).of(date.beginning_of_day)
      expect(reservation.end_time).to be_within(1.second).of(date.noon - 1.minute)

      # Half-day reservation in the afternoon
      date = Date.tomorrow
      reservation = Reservation.create!({
                                          parking_spot:,
                                          vehicle: car1,
                                          user: user1,
                                          date:,
                                          half_day: true,
                                          am: false
                                        })

      # We accept within one second as the database persisted time has less precision than ruby time
      expect(reservation.start_time).to be_within(1.second).of(date.noon)
      expect(reservation.end_time).to be_within(1.second).of(date.end_of_day)

      # Full-day reservation
      date = Date.today + 3.days
      reservation = Reservation.create!({
                                          parking_spot:,
                                          vehicle: car1,
                                          user: user1,
                                          date:,
                                          half_day: false,
                                          am: false
                                        })

      # We accept within one second as the database persisted time has less precision than ruby time
      expect(reservation.start_time).to be_within(1.second).of(date.beginning_of_day)
      expect(reservation.end_time).to be_within(1.second).of(date.end_of_day)
    end

    it 'properly creates reservation with expected attributes' do
      date = Date.today
      reservation = Reservation.create({
                                         parking_spot:,
                                         vehicle: car1,
                                         user: user1,
                                         date:
                                       })
      expected_attributes = %w[
        id
        parking_spot_id
        vehicle_id
        user_id
        cancelled
        date
        start_time
        end_time
        half_day
        am
        cancelled_at
        cancelled_by
        created_at
        updated_at
        price
      ]

      actual_attributes = reservation.attributes.map { |attribute| attribute[0] }

      expect(actual_attributes).to eql(expected_attributes)

      expect(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.match?(reservation.id)).to eql(true)
      expect(reservation.parking_spot).to eql(parking_spot)
      expect(reservation.vehicle).to eql(car1)
      expect(reservation.user).to eql(user1)
      expect(reservation.cancelled?).to eql(false)
      expect(reservation.date).to eql(date)

      # We accept within one second as the database persisted time has less precision than ruby time
      expect(reservation.start_time).to be_within(1.second).of(date.beginning_of_day)
      expect(reservation.end_time).to be_within(1.second).of(date.end_of_day)

      expect(reservation.half_day).to eql(false)
      expect(reservation.am).to eql(false)
      expect(reservation.cancelled_at).to be_nil
      expect(reservation.cancelled_by).to be_nil
      expect(reservation.created_at.respond_to?(:strftime)).to eql(true)
      expect(reservation.updated_at.respond_to?(:strftime)).to eql(true)
    end
  end
end
