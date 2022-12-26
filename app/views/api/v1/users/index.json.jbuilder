# frozen_string_literal: true

json.users @users do |user|
  json.partial! user
end
json.total_count @users.total_count
json.total_pages @users.total_pages
json.current_page @users.current_page
json.limit_per_page @users.limit_value
