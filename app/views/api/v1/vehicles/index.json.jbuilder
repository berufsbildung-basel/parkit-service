# frozen_string_literal: true

json.vehicles @vehicles do |vehicle|
  json.partial! vehicle
end
json.total_count @vehicles.total_count
json.total_pages @vehicles.total_pages
json.current_page @vehicles.current_page
json.limit_per_page @vehicles.limit_value
