# frozen_string_literal: true

# The user represents an actor in the system and must be authenticated
class User < ApplicationRecord
  devise :database_authenticatable,
         :rememberable,
         :omniauthable, omniauth_providers: %i[okta]

  has_many :reservations, dependent: :destroy
  has_many :vehicles, dependent: :destroy

  enum role: %i[user led_matrix admin]
  after_initialize :set_default_role, if: :new_record?

  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
  validates :username, presence: true, uniqueness: true

  validates_inclusion_of :role, in: roles.keys

  def role=(value)
    super
  rescue ArgumentError
    @attributes.write_cast_value('role', value)
  end

  def set_default_role
    self.role ||= :user
  end

  def exceeds_reservations_per_day?(date, reservation_id = nil)
    reservations = Reservation.active_on_day_of_user(date, self, reservation_id)

    reservations.size >= ParkitService::RESERVATION_MAX_RESERVATIONS_PER_DAY
  end

  def exceeds_reservations_per_week?(reservation)
    reservations = Reservation.active_within_business_week(reservation.date, self)

    reservations.size >= ParkitService::RESERVATION_MAX_RESERVATIONS_PER_WEEK
  end

  def self.from_omniauth(auth)
    find_or_create_by(provider: auth.provider, uid: auth.uid) do |user|
      user.email = auth.info.email
      user.username = auth.info.email
      user.password = Devise.friendly_token[0, 20]
      user.first_name = auth.info.first_name
      user.last_name = auth.info.last_name
    end
  end

  def full_name
    names = []
    names.push(last_name) unless last_name.blank?
    names.push(first_name) unless first_name.blank?
    names.join(', ')
  end

  def self.new_with_session(params, session)
    super.tap do |user|
      if ((data = session['devise.okta_data'] && session['devise.okta_data']['extra']['raw_info'])) && user.email.blank?
        user.email = data['email']
      end
    end
  end
end
