# frozen_string_literal: true

# The reservation represents a blocking of a parking spot on a specific time with a vehicle
class Reservation < ApplicationRecord
  belongs_to :parking_spot
  belongs_to :vehicle
  belongs_to :user

  before_validation :set_start_time, :set_end_time

  validates_date :date,
                 on_or_after: :today,
                 before: Date.today + ParkitService::RESERVATION_MAX_WEEKS_INTO_THE_FUTURE.weeks

  validates_datetime :start_time,
                     before: :end_time

  validates_datetime :end_time,
                     after: :start_time

  validates_date :start_time, is_at: :date
  validates_date :end_time, is_at: :date

  validates_with ReservationValidator

  scope :active, lambda {
    where(cancelled: false)
  }

  scope :active_on_date, lambda { |date|
    active.where(date:)
  }

  scope :overlapping_on_date_and_parking_spot, lambda { |date, parking_spot, user, start_time, end_time|
    active_on_date(date)
      .includes(:vehicle)
      .includes(:user)
      .where(parking_spot:)
      .where('reservations.user_id NOT IN (?)', user.id)
      .where(
        '? <= reservations.end_time AND ? >= reservations.start_time',
        start_time,
        end_time
      )
  }

  scope :active_on_day_of_user, lambda { |date, user, reservation_id = nil|
    active_on_date(date).where(user:).where.not(id: reservation_id)
  }

  scope :active_within_a_week_of_user, lambda { |reservation_date, user|
    weeks_ahead = ((reservation_date - Date.today).to_i / 7).floor
    week_start = Date.today + weeks_ahead.weeks;
    week_end = week_start + 1.weeks

    active.where(user:).where(
      'reservations.date >= ? and reservations.date <= ?',
      week_start,
      week_end
    )
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
