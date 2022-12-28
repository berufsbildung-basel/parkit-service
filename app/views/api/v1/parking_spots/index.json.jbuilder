# frozen_string_literal: true

json.parking_spots @parking_spots do |parking_spot|
  json.partial! parking_spot
end
json.total_count @parking_spots.total_count
json.total_pages @parking_spots.total_pages
json.current_page @parking_spots.current_page
json.limit_per_page @parking_spots.limit_value
