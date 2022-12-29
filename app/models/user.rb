# frozen_string_literal: true

# The user represents an actor in the system and must be authenticated
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :rememberable

  has_many :reservations
  has_many :vehicles

  enum role: %i[user led_matrix admin]
  after_initialize :set_default_role, if: :new_record?

  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
  validates :oktaId, presence: true, uniqueness: true
  validates :username, presence: true, uniqueness: true

  def set_default_role
    self.role ||= :user
  end

  def exceeds_reservations_per_day?(date, reservation_id = nil)
    reservations = Reservation.active_on_day_of_user(date, self, reservation_id)

    reservations.size >= ParkitService::RESERVATION_MAX_RESERVATIONS_PER_DAY
  end

  def exceeds_reservations_per_week?
    reservations = Reservation.active_within_max_weeks_of_user(self)

    reservations.size >= ParkitService::RESERVATION_MAX_RESERVATIONS_PER_WEEK
  end
end
