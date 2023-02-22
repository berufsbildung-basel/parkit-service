# frozen_string_literal: true

json.call(
  parking_spot,
  :id,
  :created_at,
  :updated_at,
  :number,
  :charger_available,
  :unavailable,
  :unavailability_reason
)

json.reservations parking_spot.reservations.each do |reservation|
  json.partial! 'api/v1/reservations/reservation_with_vehicle', reservation:
end
