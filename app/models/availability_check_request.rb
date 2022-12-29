# frozen_string_literal: true

# Non-persisted model used for request validation
class AvailabilityCheckRequest
  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  attr_accessor :date, :vehicle_id, :half_day, :am

  validates :date, presence: true
  validates :vehicle_id, presence: true

  validates :half_day,
            inclusion: { in: [true, false] },
            unless: proc { |r| r.half_day.nil? }

  validates :am,
            inclusion: { in: [true, false] },
            unless: proc { |r| r.am.nil? }

  validate :is_valid_date
  validate :date_on_or_after_today
  validate :before_max_weeks

  validate :vehicle_exists
  validate :user_not_disabled
  validate :user_does_not_exceed_reservations_per_day
  validate :user_does_not_exceed_reservations_per_week

  def initialize(attributes = {})
    self.date = attributes[:date] unless attributes[:date].nil?
    self.vehicle_id = attributes[:vehicle_id] unless attributes[:vehicle_id].nil?
    self.half_day = ActiveModel::Type::Boolean.new.cast(attributes[:half_day]) unless attributes[:half_day].nil?
    self.am = ActiveModel::Type::Boolean.new.cast(attributes[:am]) unless attributes[:am].nil?
  end

  def am?
    am
  end

  def half_day?
    half_day
  end

  def user
    vehicle&.user
  end

  def vehicle
    Vehicle.find(vehicle_id) if Vehicle.exists?(vehicle_id)
  end

  private

  def is_date(date)
    self.date = Date.parse(date.to_s)
    true
  rescue ArgumentError
    errors.add(:date, :invalid_date)
    false
  end

  def is_valid_date
    errors.add(:date, :invalid_date) unless is_date(date)
  end

  def date_on_or_after_today
    errors.add(:date, :must_be_on_or_after_today) unless is_date(date) && date >= Date.today
  end

  def before_max_weeks
    max_date = Date.today + ParkitService::RESERVATION_MAX_WEEKS_INTO_THE_FUTURE.weeks
    errors.add(:date, :exceeds_max_weeks_into_the_future) unless is_date(date) && date < max_date
  end

  def vehicle_exists
    errors.add(:vehicle, :blank) unless Vehicle.exists?(vehicle_id)
  end

  def user_not_disabled
    errors.add(:user, :marked_disabled) if user.present? && user.disabled?
  end

  def user_does_not_exceed_reservations_per_day
    errors.add(:user, :exceeds_max_reservations_per_day) if user.present? && user.exceeds_reservations_per_day?(date)
  end

  def user_does_not_exceed_reservations_per_week
    errors.add(:user, :exceeds_max_reservations_per_week) if user.present? && user.exceeds_reservations_per_week?
  end
end
