# frozen_string_literal: true

# A reservation booked by facilities/admin staff on behalf of someone who
# isn't a registered user. Has no associated User or Vehicle record.
class GuestReservation < Reservation
  def self.policy_class
    ReservationPolicy
  end

  validates :guest_name, presence: true
  validates :guest_license_plate, presence: true
  validate :parking_spot_is_car_type

  def requires_registered_owner?
    false
  end

  def owner_name
    guest_name
  end

  private

  def set_price
    self.price = 0.0
  end

  def parking_spot_is_car_type
    return if parking_spot.nil?

    errors.add(:parking_spot, :guests_car_only) unless parking_spot.allowed_vehicle_type == 'car'
  end
end
