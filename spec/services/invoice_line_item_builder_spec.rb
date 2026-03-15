# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvoiceLineItemBuilder do
  let(:user) do
    User.create!(username: 'test', email: 'test@example.com', first_name: 'Test', last_name: 'User',
                 preferred_language: 'de')
  end
  let(:parking_spot) { ParkingSpot.create!(number: 42) }
  let(:vehicle) { Vehicle.create!(user: user, license_plate_number: 'ZH 123', make: 'VW', model: 'Golf') }
  let(:test_date) { Date.tomorrow }
  let(:expected_date_str) { test_date.strftime('%d.%m.%Y') }

  describe '#build_description' do
    it 'formats German description for full day car' do
      reservation = Reservation.create!(
        user: user,
        vehicle: vehicle,
        parking_spot: parking_spot,
        date: test_date,
        half_day: false
      )

      builder = described_class.new(reservation, 'de')
      expect(builder.build_description).to eq("#{expected_date_str} | Platz #42 | Ganztag | Auto")
    end

    it 'formats English description' do
      reservation = Reservation.create!(
        user: user,
        vehicle: vehicle,
        parking_spot: parking_spot,
        date: test_date,
        half_day: false
      )

      builder = described_class.new(reservation, 'en')
      expect(builder.build_description).to eq("#{expected_date_str} | Spot #42 | Full day | Car")
    end

    it 'formats half day morning description' do
      reservation = Reservation.create!(
        user: user,
        vehicle: vehicle,
        parking_spot: parking_spot,
        date: test_date,
        half_day: true,
        am: true
      )

      builder = described_class.new(reservation, 'de')
      expect(builder.build_description).to eq("#{expected_date_str} | Platz #42 | Vormittag | Auto")
    end

    it 'formats half day afternoon description' do
      reservation = Reservation.create!(
        user: user,
        vehicle: vehicle,
        parking_spot: parking_spot,
        date: test_date,
        half_day: true,
        am: false
      )

      builder = described_class.new(reservation, 'de')
      expect(builder.build_description).to eq("#{expected_date_str} | Platz #42 | Nachmittag | Auto")
    end

    it 'includes cancelled suffix for cancelled reservations' do
      reservation = Reservation.create!(
        user: user,
        vehicle: vehicle,
        parking_spot: parking_spot,
        date: test_date,
        half_day: false,
        cancelled: true,
        cancelled_at: Time.current
      )

      builder = described_class.new(reservation, 'de')
      expect(builder.build_description).to include('(Storniert)')
    end

    it 'formats motorcycle description' do
      motorcycle = Vehicle.create!(user: user, license_plate_number: 'ZH 456', make: 'Yamaha', model: 'MT-07',
                                   vehicle_type: :motorcycle)
      motorcycle_spot = ParkingSpot.create!(number: 99, allowed_vehicle_type: :motorcycle)

      reservation = Reservation.create!(
        user: user,
        vehicle: motorcycle,
        parking_spot: motorcycle_spot,
        date: test_date,
        half_day: false
      )

      builder = described_class.new(reservation, 'de')
      expect(builder.build_description).to eq("#{expected_date_str} | Platz #99 | Ganztag | Motorrad")
    end
  end

  describe '#unit_price' do
    it 'returns reservation price for active reservation' do
      reservation = Reservation.create!(
        user: user,
        vehicle: vehicle,
        parking_spot: parking_spot,
        date: test_date,
        half_day: false
      )

      builder = described_class.new(reservation, 'de')
      expect(builder.unit_price).to eq(reservation.price)
    end

    it 'returns zero for cancelled reservation' do
      reservation = Reservation.create!(
        user: user,
        vehicle: vehicle,
        parking_spot: parking_spot,
        date: test_date,
        half_day: false,
        cancelled: true,
        cancelled_at: Time.current
      )

      builder = described_class.new(reservation, 'de')
      expect(builder.unit_price).to eq(0.0)
    end
  end

  describe '#artikel_nr' do
    before do
      allow(Rails.application.config).to receive(:cashctrl).and_return({
                                                                         artikel: {
                                                                           car_halfday_weekday: 'PARK-CAR-HD-WD',
                                                                           car_halfday_weekend: 'PARK-CAR-HD-WE',
                                                                           car_fullday_weekday: 'PARK-CAR-FD-WD',
                                                                           car_fullday_weekend: 'PARK-CAR-FD-WE',
                                                                           motorcycle_halfday_weekday: 'PARK-MC-HD-WD',
                                                                           motorcycle_halfday_weekend: 'PARK-MC-HD-WE',
                                                                           motorcycle_fullday_weekday: 'PARK-MC-FD-WD',
                                                                           motorcycle_fullday_weekend: 'PARK-MC-FD-WE'
                                                                         }
                                                                       })
    end

    it 'returns car fullday weekday artikel for weekday full day car reservation' do
      # Use a known weekday (Wednesday)
      weekday = Date.parse('2025-01-15') # Wednesday
      reservation = Reservation.new(
        user: user, vehicle: vehicle, parking_spot: parking_spot,
        date: weekday, half_day: false
      )
      allow(reservation).to receive(:date).and_return(weekday)

      builder = described_class.new(reservation, 'de')
      expect(builder.artikel_nr).to eq('PARK-CAR-FD-WD')
    end

    it 'returns car fullday weekend artikel for weekend full day car reservation' do
      # Use a known Saturday
      saturday = Date.parse('2025-01-18') # Saturday
      reservation = Reservation.new(
        user: user, vehicle: vehicle, parking_spot: parking_spot,
        date: saturday, half_day: false
      )
      allow(reservation).to receive(:date).and_return(saturday)

      builder = described_class.new(reservation, 'de')
      expect(builder.artikel_nr).to eq('PARK-CAR-FD-WE')
    end

    it 'returns motorcycle halfday weekday artikel for motorcycle half day' do
      motorcycle = Vehicle.create!(user: user, license_plate_number: 'ZH 789', make: 'Yamaha', model: 'MT-07',
                                   vehicle_type: :motorcycle)
      motorcycle_spot = ParkingSpot.create!(number: 100, allowed_vehicle_type: :motorcycle)

      weekday = Date.parse('2025-01-15')
      reservation = Reservation.new(
        user: user, vehicle: motorcycle, parking_spot: motorcycle_spot,
        date: weekday, half_day: true
      )
      allow(reservation).to receive(:date).and_return(weekday)

      builder = described_class.new(reservation, 'de')
      expect(builder.artikel_nr).to eq('PARK-MC-HD-WD')
    end

    it 'returns nil for cancelled reservations' do
      reservation = Reservation.new(
        user: user, vehicle: vehicle, parking_spot: parking_spot,
        date: test_date, half_day: false, cancelled: true
      )

      builder = described_class.new(reservation, 'de')
      expect(builder.artikel_nr).to be_nil
    end
  end
end
