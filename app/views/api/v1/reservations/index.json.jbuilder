# frozen_string_literal: true

json.reservations @reservations do |reservation|
  json.partial! reservation
end
json.total_count @reservations.total_count
json.total_pages @reservations.total_pages
json.current_page @reservations.current_page
json.limit_per_page @reservations.limit_value
