# frozen_string_literal: true

json.available_parking_spots @parking_spots do |parking_spot|
  json.partial! 'api/v1/parking_spots/parking_spot_with_reservations', parking_spot:
end
