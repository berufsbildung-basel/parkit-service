# frozen_string_literal: true

# The reservation represents a blocking of a parking spot on a specific time with a vehicle
class Reservation < ApplicationRecord
  belongs_to :parking_spot
  belongs_to :vehicle
  belongs_to :user

  before_validation :set_start_time, :set_end_time, :set_price

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

  attr_accessor :current_user

  def can_be_cancelled?(current_user)
    current_user.admin? || start_time > Time.now
  end

  def slot_name
    if half_day?
      am? ? 'AM' : 'PM'
    else
      'FD'
    end
  end

  scope :active, lambda {
    where(cancelled: false)
  }

  scope :cancelled, lambda {
    where(cancelled: true)
      .joins(:parking_spot)
      .order('reservations.start_time, parking_spots.number')
  }

  scope :active_on_date, lambda { |date|
    active.where(date:)
  }

  scope :active_between, lambda { |from, to|
    active.where('reservations.date between ? and ?', from, to)
  }

  scope :active_in_the_future, lambda {
    active
      .joins(:parking_spot)
      .where('reservations.date >= ?', Date.today)
      .order('reservations.start_time, parking_spots.number')
  }

  scope :active_in_the_past, lambda {
    active
      .joins(:parking_spot)
      .where('reservations.date < ?', Date.today)
      .order('reservations.start_time, parking_spots.number')
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

  scope :active_within_business_week, lambda { |reservation_date, user|
    active.where(user:).where(
      'reservations.date >= ? and reservations.date <= ?',
      reservation_date.beginning_of_week,
      reservation_date.end_of_week
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
      date.noon - 1.minute
    else
      date.end_of_day
    end
  end

  def self.to_billing_xlsx(users)
    now = DateTime.now
    xlsx_file = Tempfile.new("parkit-billing-export-#{now.strftime('%Y%m%d%H%M%s')}.xlsx")
    workbook = WriteXLSX.new(xlsx_file)

    worksheet = workbook.add_worksheet("Export #{now.month}")
    worksheet.write(0, 0, 'Lastname')
    worksheet.write(0, 1, 'Firstname')
    worksheet.write(0, 2, 'Email')

    months = []

    6.times do |num|
      month = Date.today - num.months
      months << month
      worksheet.write(0, num + 3, month.strftime('%b %y').to_s)
    end

    count = 1
    users.each do |user|
      next if user.reservations.active_between(months.last.beginning_of_month, months.first.end_of_month).empty?

      worksheet.write(count, 0, user.last_name)
      worksheet.write(count, 1, user.first_name)
      worksheet.write(count, 2, user.email)

      6.times do |num|
        month = months[num]
        sum = user.reservations.active_between(month.beginning_of_month, month.end_of_month).sum(&:price)
        worksheet.write(count, num + 3, sum)
      end

      count += 1
    end

    worksheet.write(count, 0, 'TOTAL')
    6.times do |num|
      month = months[num]
      sum = Reservation.active_between(month.beginning_of_month, month.end_of_month).sum(&:price)
      worksheet.write(count, num + 3, sum)
    end

    workbook.close

    xlsx_file.rewind
    xlsx_file.read
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

  def set_price
    self.price = half_day? ? ParkitService::RESERVATION_PRICE_HALF_DAY : ParkitService::RESERVATION_PRICE_FULL_DAY
  end
end
