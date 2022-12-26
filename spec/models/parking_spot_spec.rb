# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ParkingSpot, type: :model do
  context 'validation' do
    it 'fails creating a parking spot with no attributes set' do
      parking_spot = ParkingSpot.new
      errors = parking_spot.errors

      expect(parking_spot.valid?).to eql(false)
      expect(parking_spot.save).to eql(false)

      expect(errors.size).to eql(1)

      expect(errors.objects.first.attribute).to eql(:number)

      expect(errors.objects.first.full_message).to eql('Number is not a number')
    end

    it 'fails creating a parking spot with negative number' do
      parking_spot = ParkingSpot.create(number: -1)
      expect(parking_spot.errors.first.full_message).to eql('Number must be greater than 0')
    end

    it 'fails creating a parking spot with double number' do
      parking_spot = ParkingSpot.create(number: 1.1)
      expect(parking_spot.errors.first.full_message).to eql('Number must be an integer')
    end

    it 'fails creating a parking spot with non-number' do
      parking_spot = ParkingSpot.create(number: "test")
      expect(parking_spot.errors.first.full_message).to eql('Number is not a number')
    end

    it 'properly creates parking spot with expected attributes' do
      expected_attributes = %w[
        id
        number
        charger_available
        unavailable
        unavailability_reason
        created_at
        updated_at
      ]
      parking_spot = ParkingSpot.create(number: 2)

      actual_attributes = parking_spot.attributes.map { |attribute| attribute[0] }

      expect(actual_attributes).to eql(expected_attributes)

      expect(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.match?(parking_spot.id)).to eql(true)
      expect(parking_spot.number).to eql(2)
      expect(parking_spot.charger_available?).to eql(false)
      expect(parking_spot.unavailable?).to eql(false)
      expect(parking_spot.unavailability_reason).to be_nil
      expect(parking_spot.created_at.respond_to?(:strftime)).to eql(true)
      expect(parking_spot.updated_at.respond_to?(:strftime)).to eql(true)
    end
  end
end
