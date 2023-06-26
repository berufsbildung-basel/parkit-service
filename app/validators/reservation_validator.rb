# frozen_string_literal: true

# TODO: validate, if vehicle = motorcycle, that first a parking spot with already one motorcycle must be used, if any

# Validates the creation and updating of reservations
class ReservationValidator < ActiveModel::Validator

  def validate(reservation)
    return unless perform_validation(reservation)

    validate_user_is_not_disabled(reservation)
    validate_vehicle_belongs_to_user(reservation)
    validate_parking_spot_is_not_unavailable(reservation)
    validate_user_does_not_exceed_reservations_per_day(reservation)
    # validate_user_does_not_exceed_reservations_per_week(reservation)
    validate_overlap(reservation)
  end

  def perform_validation(reservation)
    reservation.present? &&
      reservation.user.present? &&
      reservation.vehicle.present? &&
      reservation.parking_spot.present?
  end

  def validate_user_is_not_disabled(reservation)
    return unless reservation.user.disabled?

    reservation.errors.add(:user, :marked_disabled)
  end

  def validate_parking_spot_is_not_unavailable(reservation)
    return unless reservation.parking_spot.unavailable?

    reservation.errors.add(:parking_spot, :marked_unavailable)
  end

  def validate_user_does_not_exceed_reservations_per_day(reservation)
    return unless reservation.date.present?

    return unless reservation.user.exceeds_reservations_per_day?(reservation.date, reservation.id)

    reservation.errors.add(:user, :exceeds_max_reservations_per_day)
  end

=begin
  def validate_user_does_not_exceed_reservations_per_week(reservation)
    return unless reservation.current_user.nil? || !reservation.current_user.admin?

    return unless reservation.user.exceeds_reservations_per_week?(reservation)

    reservation.errors.add(:user, :exceeds_max_reservations_per_week)
  end
=end

  def validate_vehicle_belongs_to_user(reservation)
    return unless reservation.vehicle.user.nil? || (reservation.vehicle.user.id != reservation.user.id)

    reservation.errors.add(:vehicle, :does_not_belong_to_reservation_user)
  end

  def validate_overlap(reservation)
    overlapping_reservations = Reservation.overlapping_on_date_and_parking_spot(
      reservation.date,
      reservation.parking_spot,
      reservation.user,
      reservation.start_time,
      reservation.end_time
    )

    return unless overlapping_reservations.size.positive?

    reservation.errors.add(:base, :overlaps_with_existing_reservation)
  end
end
