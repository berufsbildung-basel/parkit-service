# frozen_string_literal: true

# TODO: does not yet validate user restrictions: validate and add custom error for 403 in controller

# Non-persisted model used for request validation
class AvailabilityCheckRequest
  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  attr_accessor :date, :vehicle_id, :half_day, :am

  # We use STRICT validations to have the model raise an error when calling *.valid?*

  validates :date, presence: true, strict: true
  validate :is_date
  validate :date_on_or_after_today
  validate :before_max_weeks

  validates :vehicle_id, presence: true, strict: true

  validate :vehicle_exists
  validate :user_not_disabled
  validate :user_does_not_exceed_reservations_per_day
  validate :user_does_not_exceed_reservations_per_week

  validates :half_day,
            inclusion: { in: [true, false] },
            strict: true,
            unless: proc { |r| r.half_day.nil? }

  validates :am,
            inclusion: { in: [true, false] },
            strict: true,
            unless: proc { |r| r.am.nil? }

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
    vehicle.user
  end

  def vehicle
    Vehicle.find(vehicle_id)
  end

  private

  def is_date
    Date.parse(date)
    self.date = Date.parse(date)
  rescue ArgumentError
    raise InvalidDateError('Date is invalid')
  end

  def date_on_or_after_today
    raise InvalidDateError, 'Date must be on or after today' unless date >= Date.today
  end

  def before_max_weeks
    max_date = Date.today + ParkitService::RESERVATION_MAX_WEEKS_INTO_THE_FUTURE.weeks
    raise InvalidDateError, 'Date is too far into the future' unless date < max_date
  end

  def vehicle_exists
    raise VehicleNotFoundError unless Vehicle.exists?(vehicle_id)
  end

  def user_not_disabled
    raise UserDisabledError if user.disabled?
  end

  def user_does_not_exceed_reservations_per_day
    raise UserExceedsReservationsPerDayError if user.exceeds_reservations_per_day?(date)
  end

  def user_does_not_exceed_reservations_per_week
    raise UserExceedsReservationsPerWeekError if user.exceeds_reservations_per_week?
  end

  # Custom error parent class
  class AvailabilityCheckError < StandardError
    def initialize(msg = nil)
      super
    end
  end

  # Custome error
  class InvalidDateError < AvailabilityCheckError
    def initialize(msg = nil)
      super
    end
  end

  # Custom error
  class UserDisabledError < AvailabilityCheckError
    def message
      'User is disabled'
    end
  end

  # Custom error
  class UserExceedsReservationsPerDayError < AvailabilityCheckError
    def message
      'User exceeds reservations per day'
    end
  end

  # Custom error
  class UserExceedsReservationsPerWeekError < AvailabilityCheckError
    def message
      'User exceeds reservations per week'
    end
  end

  # Custom error
  class VehicleNotFoundError < AvailabilityCheckError
    def message
      'Vehicle not found'
    end
  end
end
