# frozen_string_literal: true

# The user represents an actor in the system and must be authenticated
class User < ApplicationRecord
  devise :database_authenticatable,
         :trackable,
         :omniauthable, omniauth_providers: %i[okta]

  has_many :reservations, dependent: :destroy
  has_many :vehicles, dependent: :destroy
  has_many :invoices, dependent: :destroy
  has_many :journal_entries, dependent: :destroy
  has_many :executed_billing_periods, class_name: 'BillingPeriod', foreign_key: :executed_by_id, dependent: :nullify

  enum role: %i[user led_matrix admin]
  enum billing_type: { standard: 0, prepaid: 1, exempt: 2 }

  scope :billable, -> { where(billing_type: %i[standard prepaid]) }
  scope :standard_billing, -> { where(billing_type: :standard) }
  scope :prepaid_billing, -> { where(billing_type: :prepaid) }
  scope :exempt_billing, -> { where(billing_type: :exempt) }
  after_initialize :set_default_role, if: :new_record?

  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
  validates :username, presence: true, uniqueness: true

  validates_inclusion_of :role, in: roles.keys

  # Address validation - require all fields if any are present
  validates :address_line1, :postal_code, :city, :country_code,
            presence: true,
            if: :any_address_field_present?

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

  def address_complete?
    address_line1.present? && postal_code.present? && city.present? && country_code.present?
  end

  def full_address_line
    [address_line1, address_line2].compact_blank.join(', ')
  end

  private

  def any_address_field_present?
    address_line1.present? || address_line2.present? || postal_code.present? || city.present?
  end
end
