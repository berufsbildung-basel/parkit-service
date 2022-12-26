# frozen_string_literal: true

# A parking spot can hold reservations
class ParkingSpot < ApplicationRecord
  has_many :reservations

  validates :number, numericality: { only_integer: true, greater_than: 0 }, uniqueness: true
end
