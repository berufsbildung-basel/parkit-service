# frozen_string_literal: true

# The reservation represents a blocking of a parking spot on a specific time with a vehicle
class Reservation < ApplicationRecord
  belongs_to :parking_spot
  belongs_to :vehicle
  belongs_to :user

  before_validation :set_start_time, :set_end_time

  validates_date :date

  validates_date :date, on_or_after: :today

  validates_date :date,
                 before: Date.today + ParkitService::RESERVATION_MAX_WEEKS_INTO_THE_FUTURE.weeks

  validates_datetime :start_time, :end_time

  validates_datetime :start_time, before: :end_time

  validates_date :start_time, on: :date

  validates_date :end_time, on: :date

  validates_with ReservationValidator

  scope :active, lambda {
    where(cancelled: false)
  }

  scope :active_on_date, lambda { |date|
    active.where(date:)
  }

  scope :overlapping_on_date_and_parking_spot, lambda { |reservation|
    active_on_date(reservation.date)
      .includes(:vehicle)
      .includes(:user)
      .where(parking_spot: reservation.parking_spot)
      .where('user_id not in (?)', reservation.user.id)
      .where(
        '? <= reservations.end_time and ? >= reservations.start_time',
        reservation.start_time,
        reservation.end_time
      )
  }

  scope :active_on_day_of_user, lambda { |date, user|
    active_on_date(date).where(date:, user:)
  }
  scope :active_within_max_weeks_of_user, lambda { |user|
    active.where(user:).where(
      'reservations.date >= ? and reservations.date <= ?',
      Date.today,
      Date.today + ParkitService::RESERVATION_MAX_WEEKS_INTO_THE_FUTURE.weeks
    )
  }

  def self.calculate_start_time(date, half_day, am)
    if half_day && !am
      date.noon
    else
      date.beginning_of_day
    end
  end

  def self.calculate_end_time(date, half_day, am)
    if half_day && am
      date.noon
    else
      date.end_of_day
    end

  end

  private

  # Set the start and end time of the reservation based on whether
  # It is a half- or full-day reservation.
  def set_start_time
    return unless date.present?

    self.start_time = Reservation.calculate_start_time(date, half_day, am)
  end

  def set_end_time
    return unless date.present?

    self.end_time = Reservation.calculate_end_time(date, half_day, am)
  end
end
