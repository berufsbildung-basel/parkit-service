# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vehicle, type: :model do

  user = nil

  before do
    user = User.create({
                         oktaId: 'ABCD1234@AdobeOrg',
                         username: 'some-user',
                         email: 'some-user@adobe.com',
                         first_name: 'Jane',
                         last_name: 'Doe'
                       })
  end

  context 'validation' do
    it 'fails creating a vehicle with no attributes set' do
      vehicle = Vehicle.new
      errors = vehicle.errors

      expect(vehicle.valid?).to eql(false)
      expect(vehicle.save).to eql(false)

      expect(errors.size).to eql(4)

      expect(errors.objects.first.attribute).to eql(:user)
      expect(errors.objects.second.attribute).to eql(:license_plate_number)
      expect(errors.objects.third.attribute).to eql(:make)
      expect(errors.objects.fourth.attribute).to eql(:model)

      expect(errors.objects.first.full_message).to eql('User must exist')
      expect(errors.objects.second.full_message).to eql('License plate number can\'t be blank')
      expect(errors.objects.third.full_message).to eql("Make can't be blank")
      expect(errors.objects.fourth.full_message).to eql("Model can't be blank")
    end
  end

  context 'creation' do
    it 'properly creates vehicle with expected attributes' do
      expected_attributes = %w[
        id
        user_id
        ev
        license_plate_number
        make
        model
        vehicle_type
        created_at
        updated_at
      ]
      vehicle = Vehicle.create(
        license_plate_number: 'BL 1234',
        make: 'Ford',
        model: 'Focus',
        user:
      )

      actual_attributes = vehicle.attributes.map { |attribute| attribute[0] }

      expect(actual_attributes).to eql(expected_attributes)

      expect(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.match?(vehicle.id)).to eql(true)
      expect(vehicle.license_plate_number).to eql('BL 1234')
      expect(vehicle.make).to eql('Ford')
      expect(vehicle.model).to eql('Focus')
      expect(vehicle.vehicle_type).to eql('car')
      expect(vehicle.car?).to eql(true)
      expect(vehicle.ev?).to eql(false)
      expect(vehicle.user).to eql(user)
      expect(vehicle.created_at.respond_to?(:strftime)).to eql(true)
      expect(vehicle.updated_at.respond_to?(:strftime)).to eql(true)
    end
  end
end
