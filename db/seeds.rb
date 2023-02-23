# frozen_string_literal: true

# Create users
192.times do |i|

  role = (i % 11).zero? ? :admin : :user

  user = User.create!(
    email: Faker::Internet.unique.email(domain: 'adobe.com'),
    username: Faker::Internet.unique.username,
    role:,
    password: 'test',
    first_name: Faker::Name.first_name,
    last_name: Faker::Name.last_name
  )

  is_ev = (i % 10).zero? ? true : false
  vehicle_type = (i % 18).zero? ? :motorcycle : :car

  Vehicle.create!(
    user:,
    ev: is_ev,
    license_plate_number: Faker::Vehicle.unique.license_plate,
    make: Faker::Vehicle.make,
    model: Faker::Vehicle.model,
    vehicle_type:
  )
end

8.times do |i|
  is_charger_available = (i % 2).zero? ? true : false

  ParkingSpot.create!(
    number: i + 1,
    charger_available: is_charger_available
  )
end
