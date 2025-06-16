# frozen_string_literal: false

# A parking spot can hold reservations
class ParkingSpot < ApplicationRecord
  has_many :reservations, dependent: :destroy

  validates :number, numericality: { only_integer: true, greater_than: 0 }, uniqueness: true

  enum allowed_vehicle_type: { car: 0, motorcycle: 1 }

  validates :allowed_vehicle_type, presence: true, inclusion: { in: allowed_vehicle_types.keys }

  def self.status_for_user_next_days(_user, num_days)
    result = {}

    return result if num_days <= 0

    (0..(num_days.to_i - 1)).each do |n|
      date = Date.today + n.days
      parking_spots = ParkingSpot.with_reservations_on_date(date)
      result[date.cweek] = {} if result[date.cweek].nil?
      result[date.cweek][date] = parking_spots
    end

    result
  end

  scope :available, lambda {
    where(unavailable: false)
  }

  # Returns available parking spots for a given date, vehicle and full-/half-day filter.
  # The vehicle owner is considered in the check.
  scope :available_on_date_and_time_for_vehicle_type, lambda { |date, vehicle, half_day, am|
    available.select do |parking_spot|
      start_time = Reservation.calculate_start_time(date, half_day, am)
      end_time = Reservation.calculate_end_time(date, half_day, am)

      reservations = Reservation.overlapping_on_date_and_parking_spot(
        date,
        parking_spot,
        vehicle.user,
        start_time,
        end_time
      )

      reservations.empty?
    end
  }

  # List parking spots and any reservations + vehicles on the given date
  scope :with_reservations_on_date, lambda { |date|
    join_sql = 'LEFT OUTER JOIN reservations ON ('
    join_sql << ' reservations.parking_spot_id = parking_spots.id'
    join_sql << ' and reservations.cancelled = %s'
    join_sql << ' and reservations.date = \'%s\''
    join_sql << ')'

    # We use custom SQL here, as semantic rails does not yet support left *outer* join conditions
    sanitized_sql = sanitize_sql_array([join_sql, false, date])

    all.joins(sanitized_sql).order(:number)
  }
end
