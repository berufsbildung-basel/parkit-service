# frozen_string_literal: true

require 'concerns/vehicle_type'

# The vehicle belongs to a user and can be used for reservations
class Vehicle < ApplicationRecord
  belongs_to :user

  has_many :reservations, dependent: :destroy

  enum vehicle_type: VehicleType::TYPES
  after_initialize :set_default_vehicle_type, if: :new_record?

  validates :license_plate_number, presence: true, uniqueness: true
  validates :make, presence: true
  validates :model, presence: true

  def set_default_vehicle_type
    self.vehicle_type ||= :car
  end

  def full_title
    "#{license_plate_number} (#{make} / #{model})"
  end
end
