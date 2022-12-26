# frozen_string_literal: true

# The vehicle belongs to a user and can be used for reservations
class Vehicle < ApplicationRecord
  belongs_to :user

  has_many :reservations

  enum vehicle_type: %i[car motorcycle]
  after_initialize :set_default_vehicle_type, if: :new_record?

  validates :license_plate_number, presence: true, uniqueness: true
  validates :make, presence: true
  validates :model, presence: true

  def set_default_vehicle_type
    self.vehicle_type ||= :car
  end
end
