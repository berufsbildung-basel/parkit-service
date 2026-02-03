# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvoiceLineItem, type: :model do
  let(:user) do
    User.create!(username: 'test', email: 'test@example.com', first_name: 'Test', last_name: 'User')
  end
  let(:parking_spot) { ParkingSpot.create!(number: 1) }
  let(:vehicle) { Vehicle.create!(user: user, license_plate_number: 'ZH 123', make: 'Test', model: 'Car') }
  let(:reservation) do
    Reservation.create!(user: user, vehicle: vehicle, parking_spot: parking_spot, date: Date.today + 1.day)
  end
  let(:invoice) do
    Invoice.create!(user: user, cashctrl_person_id: 123, period_start: Date.new(2025, 1, 1), period_end: Date.new(2025, 1, 31))
  end

  describe 'validations' do
    it 'requires invoice' do
      item = InvoiceLineItem.new(reservation: reservation, description: 'Test', unit_price: 20)
      expect(item).not_to be_valid
    end

    it 'requires description' do
      item = InvoiceLineItem.new(invoice: invoice, reservation: reservation, unit_price: 20)
      expect(item).not_to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to invoice' do
      item = InvoiceLineItem.new
      expect(item).to respond_to(:invoice)
    end

    it 'belongs to reservation' do
      item = InvoiceLineItem.new
      expect(item).to respond_to(:reservation)
    end
  end
end
