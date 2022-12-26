# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReservationValidator, type: :validator do
  context 'init' do
    it 'creates a reservation validator' do
      validator = ReservationValidator.new

      expect(validator.kind).to be(:reservation)
      expect(validator.class).to be(ReservationValidator)
      expect(validator.respond_to?(:validate)).to eql(true)
    end

    it 'does not validate if no reservation is given' do
      reservation = nil

      ReservationValidator.new.validate(reservation)

      expect(reservation).to be_nil
    end

    it 'does not validate if no user is given' do
      reservation = Reservation.new

      ReservationValidator.new.validate(reservation)

      expect(reservation.errors.size).to eql(0)
    end

    it 'does not validate if no vehicle is given' do
      reservation = Reservation.new(user: User.new)

      ReservationValidator.new.validate(reservation)

      expect(reservation.errors.size).to eql(0)
    end

    it 'does not validate if no parking_spot is given' do
      reservation = Reservation.new(user: User.new, vehicle: Vehicle.new)

      ReservationValidator.new.validate(reservation)

      expect(reservation.errors.size).to eql(0)
    end

    it 'validates if reservation, user, vehicle and parking spot are present' do
      reservation = Reservation.new(user: User.new, vehicle: Vehicle.new, parking_spot: ParkingSpot.new)

      ReservationValidator.new.validate(reservation)

      expect(reservation.errors.size).to eql(1)
      expect(reservation.errors.first.full_message).to eql('Vehicle does not belong to the reservation user')
    end
  end

  context 'validation' do
    parking_spot = nil
    unavailable_parking_spot = nil

    user1 = nil
    user2 = nil
    user3 = nil

    car1 = nil
    car2 = nil

    motorcycle1 = nil
    motorcycle2 = nil
    motorcycle3 = nil

    disabled_user = nil
    disabled_user_car = nil

    before(:each) do
      parking_spot = ParkingSpot.create({ number: 2 })
      unavailable_parking_spot = ParkingSpot.create({ number: 3, unavailable: true, unavailability_reason: 'test' })
      user1 = User.create!({
                             oktaId: 'ABCD1234@AdobeOrg',
                             username: 'some-user1',
                             email: 'some-user1@adobe.com',
                             first_name: 'Jane',
                             last_name: 'Doe'
                           })
      car1 = Vehicle.create!({
                               license_plate_number: 'BL 1234',
                               make: 'Ford',
                               model: 'Focus',
                               user: user1
                             })
      motorcycle1 = Vehicle.create!({
                                      license_plate_number: 'BL 9123',
                                      make: 'Yamaha',
                                      model: 'GTX',
                                      vehicle_type: 'motorcycle',
                                      user: user1
                                    })

      user2 = User.create!({
                             oktaId: 'EFGH5678@AdobeOrg',
                             username: 'some-user2',
                             email: 'some-user2@adobe.com',
                             first_name: 'John',
                             last_name: 'Eod'
                           })
      car2 = Vehicle.create!({
                               license_plate_number: 'BS 5678',
                               make: 'Ford',
                               model: 'Focus',
                               user: user2
                             })
      motorcycle2 = Vehicle.create!({
                                      license_plate_number: 'BS 9978',
                                      make: 'Yamaha',
                                      model: 'GTX',
                                      vehicle_type: 'motorcycle',
                                      user: user2
                                    })

      user3 = User.create!({
                             oktaId: 'HAE1312@AdobeOrg',
                             username: 'some-user3',
                             email: 'some-user3@adobe.com',
                             first_name: 'Ella',
                             last_name: 'BElla'
                           })
      motorcycle3 = Vehicle.create!({
                                      license_plate_number: 'LÖ WE 432',
                                      make: 'Triumph',
                                      model: '12',
                                      vehicle_type: 'motorcycle',
                                      user: user3
                                    })
      disabled_user = User.create!({
                                     oktaId: 'dis1234@AdobeOrg',
                                     username: 'disabled-user',
                                     email: 'disabled-user@adobe.com',
                                     first_name: 'Dis',
                                     last_name: 'Abled',
                                     disabled: true
                                   })
      disabled_user_car = Vehicle.create!({
                                            license_plate_number: '42 SAC 43',
                                            make: 'Renault',
                                            model: 'Mégane',
                                            user: disabled_user
                                          })
    end

    after(:each) do
      Reservation.destroy_all
      Vehicle.destroy_all
      User.destroy_all
      ParkingSpot.destroy_all
    end


    it 'rejects creating a reservation where the user doesn\'t own the vehicle' do
      date = Date.today
      reservation = Reservation.create({
                                         parking_spot:,
                                         vehicle: car2,
                                         user: user1,
                                         date:
                                       })
      errors = reservation.errors

      expect(errors.size).to eql(1)
      expect(errors.first.full_message).to eql('Vehicle does not belong to the reservation user')
    end

    it 'rejects creating a reservation for a disabled user' do
      date = Date.today
      reservation = Reservation.create({
                                         parking_spot:,
                                         vehicle: disabled_user_car,
                                         user: disabled_user,
                                         date:
                                       })
      errors = reservation.errors

      expect(errors.size).to eql(1)
      expect(errors.first.full_message).to eql('User has been marked disabled')
    end

    it 'rejects creating a reservation on a parking spot marked unavailable' do
      date = Date.today
      reservation = Reservation.create({
                                         parking_spot: unavailable_parking_spot,
                                         vehicle: car1,
                                         user: user1,
                                         date:
                                       })
      errors = reservation.errors

      expect(errors.size).to eql(1)
      expect(errors.first.full_message).to eql('Parking spot has been marked unavailable')
    end

    it 'rejects creating a reservation when the user exceeds the daily maximum' do
      date = Date.today
      Reservation.create!({
                            parking_spot:,
                            vehicle: car1,
                            user: user1,
                            date:
                          })
      reservation = Reservation.create({
                                         parking_spot:,
                                         vehicle: car1,
                                         user: user1,
                                         date:
                                       })
      errors = reservation.errors

      expect(errors.size).to eql(1)
      expect(errors.first.full_message).to eql('User already has a reservation on that day')
    end

    it 'rejects creating a reservations that overlap' do
      date = Date.today
      Reservation.create!({
                            parking_spot:,
                            vehicle: car1,
                            user: user1,
                            date:
                          })
      Reservation.create!({
                            parking_spot:,
                            vehicle: motorcycle1,
                            user: user1,
                            date: date + 1.day
                          })

      # Full-day reservation
      reservation = Reservation.create({
                                         parking_spot:,
                                         vehicle: car2,
                                         user: user2,
                                         date:
                                       })

      errors = reservation.errors

      expect(errors.size).to eql(1)
      expect(errors.first.full_message)
        .to eql('Reservation overlaps with existing reservation on that day and parking spot')

      # Half-day reservation in the afternoon
      reservation = Reservation.create({
                                         parking_spot:,
                                         vehicle: car2,
                                         user: user2,
                                         date:,
                                         half_day: true
                                       })

      errors = reservation.errors

      expect(errors.size).to eql(1)
      expect(errors.first.full_message)
        .to eql('Reservation overlaps with existing reservation on that day and parking spot')

      # Half-day reservation in the morning
      reservation = Reservation.create({
                                         parking_spot:,
                                         vehicle: car2,
                                         user: user2,
                                         date:,
                                         half_day: true,
                                         am: true
                                       })

      errors = reservation.errors

      expect(errors.size).to eql(1)
      expect(errors.first.full_message)
        .to eql('Reservation overlaps with existing reservation on that day and parking spot')

      # Should allow creating an overlapping motorcycle reservation
      Reservation.create!({
                            parking_spot:,
                            vehicle: motorcycle2,
                            user: user2,
                            date: date + 1.day
                          })

      # Should reject third motorcycle on same spot
      reservation = Reservation.create({
                                         parking_spot:,
                                         vehicle: motorcycle3,
                                         user: user3,
                                         date: date + 1.day
                                       })

      errors = reservation.errors

      expect(errors.size).to eql(1)
      expect(errors.first.full_message)
        .to eql('Reservation overlaps with existing reservation on that day and parking spot')
    end

    it 'rejects creating a reservation when the user exceeds the weekly maximum' do
      Reservation.create!({
                            parking_spot:,
                            vehicle: car1,
                            user: user1,
                            date: Date.today
                          })
      Reservation.create!({
                            parking_spot:,
                            vehicle: car1,
                            user: user1,
                            date: Date.tomorrow
                          })
      Reservation.create!({
                            parking_spot:,
                            vehicle: car1,
                            user: user1,
                            date: Date.today + 3.days
                          })

      reservation = Reservation.create({
                                         parking_spot:,
                                         vehicle: car1,
                                         user: user1,
                                         date: Date.today + 4.days
                                       })

      errors = reservation.errors

      expect(errors.size).to eql(1)
      expect(errors.first.full_message).to eql('User exceeds maximum reservations per week')
    end
  end
end
