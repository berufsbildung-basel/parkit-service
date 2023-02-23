# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Parking Spots', type: :request do
  let!(:parking_spot) do
    ParkingSpot.create(number: 2)
  end

  describe 'POST /parking_spots' do
    it 'renders a successful response' do
      post api_v1_parking_spots_url, params: { number: 4 }

      expect(response).to have_http_status(201)
    end

    it 'renders JSON' do
      post api_v1_parking_spots_url, params: { number: 4 }

      expect(response.content_type).to eq('application/json; charset=utf-8')
    end

    it 'renders the parking spot template' do
      post api_v1_parking_spots_url, params: { number: 4 }

      expect(response).to render_template('api/v1/parking_spots/_parking_spot')
    end

    it 'creates a new parking spot' do
      post api_v1_parking_spots_url, params: { number: 4 }

      expect(response).to have_http_status(201)

      new_parking_spot = ParkingSpot.last
      json = JSON.parse(response.body).deep_symbolize_keys

      expect(json[:id]).to eq(new_parking_spot.id)
      expect(json[:number]).to eq(new_parking_spot.number)
      expect(json[:charger_available]).to eq(new_parking_spot.charger_available?)
      expect(json[:unavailable]).to eq(new_parking_spot.unavailable?)
      expect(json[:unavailability_reason]).to be_nil

      # We accept within one second as the database persisted time has less precision than ruby time
      expect(Time.zone.parse(json[:created_at])).to be_within(1.second).of(new_parking_spot.created_at)
      expect(Time.zone.parse(json[:updated_at])).to be_within(1.second).of(new_parking_spot.updated_at)
    end
  end

  describe 'GET /parking_spots/availability' do
    date = Date.today
    date_string = date.to_s

    reservation_date = date + 3.days
    reservation_date_string = reservation_date.to_s

    reservation_date_2 = date + 4.days
    reservation_date_string_2 = reservation_date_2.to_s

    user = nil
    vehicle_car = nil

    vehicle_car_2 = nil
    vehicle_motorcycle_2 = nil

    before(:each) do
      user = User.create!({
                            username: Faker::Internet.username,
                            email: Faker::Internet.email,
                            first_name: Faker::Name.first_name,
                            last_name: Faker::Name.last_name
                          })
      vehicle_car = Vehicle.create!({
                                      license_plate_number: Faker::Vehicle.unique.license_plate,
                                      make: Faker::Vehicle.make,
                                      model: Faker::Vehicle.model,
                                      user:
                                    })

      vehicle_motorcycle = Vehicle.create!({
                                             license_plate_number: Faker::Vehicle.unique.license_plate,
                                             make: Faker::Vehicle.make,
                                             model: Faker::Vehicle.model,
                                             user:,
                                             vehicle_type: 'motorcycle'
                                           })

      Reservation.create!({
                            date: reservation_date,
                            vehicle: vehicle_car,
                            parking_spot:,
                            user:,
                            half_day: false,
                            am: false
                          })

      Reservation.create!({
                            date: reservation_date_2,
                            vehicle: vehicle_motorcycle,
                            parking_spot:,
                            user:,
                            half_day: false,
                            am: false
                          })

      user2 = User.create!({
                             username: Faker::Internet.username,
                             email: Faker::Internet.email,
                             first_name: Faker::Name.first_name,
                             last_name: Faker::Name.last_name
                           })
      vehicle_car_2 = Vehicle.create!({
                                        license_plate_number: Faker::Vehicle.unique.license_plate,
                                        make: Faker::Vehicle.make,
                                        model: Faker::Vehicle.model,
                                        user: user2,
                                      })
      vehicle_motorcycle_2 = Vehicle.create!({
                                               license_plate_number: Faker::Vehicle.unique.license_plate,
                                               make: Faker::Vehicle.make,
                                               model: Faker::Vehicle.model,
                                               user: user2,
                                               vehicle_type: 'motorcycle'
                                             })
    end

    it 'rejects request without any parameters' do
      get api_v1_parking_spots_availability_url

      expect(response).to have_http_status(400)

      errors = JSON.parse(response.body).deep_symbolize_keys[:errors]

      expect(errors[0][:title]).to eq('The parameter \'vehicle_id\' is required')
    end

    it 'rejects request without vehicle' do
      get api_v1_parking_spots_availability_url, params: {
        date: reservation_date
      }

      expect(response).to have_http_status(400)

      errors = JSON.parse(response.body).deep_symbolize_keys[:errors]

      expect(errors[0][:title]).to eq('The parameter \'vehicle_id\' is required')
    end

    it 'rejects request with non-existing vehicle' do
      get api_v1_parking_spots_availability_url, params: {
        date: date_string,
        parking_spot_id: parking_spot.id,
        vehicle_id: 'does-not-exist'
      }

      expect(response).to have_http_status(404)

      errors = JSON.parse(response.body).deep_symbolize_keys[:errors]

      expect(errors[0][:title]).to eq('Could not find vehicle')
    end

    it 'rejects request with invalid date' do
      get api_v1_parking_spots_availability_url, params: {
        vehicle_id: vehicle_car.id,
        date: 'invalid-date'
      }

      expect(response).to have_http_status(400)

      errors = JSON.parse(response.body).deep_symbolize_keys[:errors]

      expect(errors[0][:title]).to eq('Invalid date')
    end

    it 'rejects request with date in the past' do
      get api_v1_parking_spots_availability_url, params: {
        vehicle_id: vehicle_car.id,
        date: (Date.today - 1.week).to_s
      }

      expect(response).to have_http_status(400)

      errors = JSON.parse(response.body).deep_symbolize_keys[:errors]

      expect(errors[0][:title]).to eq('Date must be on or after today')
    end

    it 'rejects request with date further in the future than max weeks' do
      get api_v1_parking_spots_availability_url, params: {
        vehicle_id: vehicle_car.id,
        date: (date + ParkitService::RESERVATION_MAX_WEEKS_INTO_THE_FUTURE.week).to_s
      }

      expect(response).to have_http_status(400)

      errors = JSON.parse(response.body).deep_symbolize_keys[:errors]

      expect(errors[0][:title]).to eq('Date exceeds maximum weeks into the future')
    end

    it 'rejects request with disabled user' do
      user.update!({ disabled: true })

      get api_v1_parking_spots_availability_url, params: {
        vehicle_id: vehicle_car.id,
        date: date_string
      }

      expect(response).to have_http_status(403)

      errors = JSON.parse(response.body).deep_symbolize_keys[:errors]

      expect(errors[0][:title]).to eq('User is disabled')
    end

    it 'rejects request when user exceeds reservations per day' do
      allow_any_instance_of(User).to receive(:exceeds_reservations_per_day?).and_return(true)

      get api_v1_parking_spots_availability_url, params: {
        vehicle_id: vehicle_car.id,
        date: date_string
      }

      expect(response).to have_http_status(403)

      errors = JSON.parse(response.body).deep_symbolize_keys[:errors]

      expect(errors[0][:title]).to eq('User exceeds maximum reservations per day')
    end

    it 'rejects request when user exceeds reservations per week' do
      allow_any_instance_of(User).to receive(:exceeds_reservations_per_week?).and_return(true)

      get api_v1_parking_spots_availability_url, params: {
        vehicle_id: vehicle_car.id,
        date: date_string
      }

      expect(response).to have_http_status(403)

      errors = JSON.parse(response.body).deep_symbolize_keys[:errors]

      expect(errors[0][:title]).to eq('User exceeds maximum reservations per week')
    end

    it 'renders a successful response' do
      get api_v1_parking_spots_availability_url, params: {
        vehicle_id: vehicle_car.id,
        date: date_string
      }

      expect(response).to have_http_status(200)
    end

    it 'renders JSON' do
      get api_v1_parking_spots_availability_url, params: {
        vehicle_id: vehicle_car.id,
        date: date_string
      }

      expect(response.content_type).to eq('application/json; charset=utf-8')
    end

    it 'renders the parking spot template' do
      get api_v1_parking_spots_availability_url, params: {
        vehicle_id: vehicle_car.id,
        date: date_string
      }

      expect(response).to render_template(:check_availability)
    end

    it 'filters unavailable parking spots' do
      get api_v1_parking_spots_availability_url, params: {
        vehicle_id: vehicle_car_2.id,
        date: reservation_date_string,
        half_day: true,
        am: true
      }

      json = JSON.parse(response.body).deep_symbolize_keys

      expect(json[:available_parking_spots].size).to eq(0)
    end

    it 'can reserve for motorcycle on same spot' do
      get api_v1_parking_spots_availability_url, params: {
        vehicle_id: vehicle_motorcycle_2.id,
        date: reservation_date_string_2,
        half_day: true,
        am: true
      }

      json = JSON.parse(response.body).deep_symbolize_keys

      expect(json[:available_parking_spots].size).to eq(1)
    end

    it 'lists available parking spots' do
      get api_v1_parking_spots_availability_url, params: {
        vehicle_id: vehicle_car.id,
        date: date_string,
      }

      json = JSON.parse(response.body).deep_symbolize_keys

      expect(json[:available_parking_spots].size).to eq(1)

      expect(json[:available_parking_spots][0][:id]).to eq(parking_spot.id)
      expect(json[:available_parking_spots][0][:number]).to eq(parking_spot.number)
      expect(json[:available_parking_spots][0][:charger_available]).to eq(parking_spot.charger_available?)
      expect(json[:available_parking_spots][0][:unavailable]).to eq(parking_spot.unavailable?)
      expect(json[:available_parking_spots][0][:unavailability_reason]).to be_nil

      # We accept within one second as the database persisted time has less precision than ruby time
      expect(Time.zone.parse(json[:available_parking_spots][0][:created_at])).to be_within(1.second).of(parking_spot.created_at)
      expect(Time.zone.parse(json[:available_parking_spots][0][:updated_at])).to be_within(1.second).of(parking_spot.updated_at)
    end
  end

  describe 'POST /parking_spots/today' do
    it 'renders a successful response' do
      get api_v1_parking_spots_today_url

      expect(response).to have_http_status(200)
    end

    it 'renders JSON' do
      get api_v1_parking_spots_today_url

      expect(response.content_type).to eq('application/json; charset=utf-8')
    end

    it 'renders the parking spot template' do
      get api_v1_parking_spots_today_url

      expect(response).to render_template(:today)
    end
  end

  describe 'DELETE /parking_spots/{id}' do
    it 'renders a successful response' do
      delete api_v1_parking_spot_url(parking_spot.id)

      expect(response).to have_http_status(204)
    end

    it 'renders without content type' do
      delete api_v1_parking_spot_url(parking_spot.id)

      expect(response.content_type).to eq(nil)
    end

    it 'has no content' do
      delete api_v1_parking_spot_url(parking_spot.id)

      expect(response.body).to eq('')
    end

    it 'deletes a parking spot' do
      expect(ParkingSpot.all.size).to eq(1)

      delete api_v1_parking_spot_url(parking_spot.id)

      expect(ParkingSpot.all.size).to eq(0)
    end
  end

  describe 'PUT /parking_spots/{id}/set_unavailable' do
    it 'returns not found for non-existing parking spot' do
      put api_v1_parking_spot_set_unavailable_url('non-existing-id')

      expect(response).to have_http_status(404)

      errors = JSON.parse(response.body).deep_symbolize_keys[:errors]

      expect(errors[0][:title]).to eq('Could not find parking spot')
    end

    it 'renders a successful response' do
      put api_v1_parking_spot_set_unavailable_url(parking_spot.id)

      expect(response).to have_http_status(200)
    end

    it 'renders JSON' do
      put api_v1_parking_spot_set_unavailable_url(parking_spot.id)

      expect(response.content_type).to eq('application/json; charset=utf-8')
    end

    it 'renders the parking spot template' do
      put api_v1_parking_spot_set_unavailable_url(parking_spot.id)

      expect(response).to render_template('api/v1/parking_spots/_parking_spot')
    end

    it 'sets parking spot unavailable' do
      put api_v1_parking_spot_set_unavailable_url(parking_spot.id), params: {
        unavailability_reason: 'test'
      }

      parking_spot.reload

      expect(JSON.parse(response.body).deep_symbolize_keys[:unavailable]).to eq(true)
      expect(parking_spot.unavailable?).to eq(true)
      expect(parking_spot.unavailability_reason).to eq('test')
    end
  end

  describe 'PUT /parking_spots/{id}/set_available' do
    it 'returns not found for non-existing parking spot' do
      put api_v1_parking_spot_set_available_url('non-existing-id')

      expect(response).to have_http_status(404)

      errors = JSON.parse(response.body).deep_symbolize_keys[:errors]

      expect(errors[0][:title]).to eq('Could not find parking spot')
    end

    it 'renders a successful response' do
      put api_v1_parking_spot_set_available_url(parking_spot.id)

      expect(response).to have_http_status(200)
    end

    it 'renders JSON' do
      put api_v1_parking_spot_set_available_url(parking_spot.id)

      expect(response.content_type).to eq('application/json; charset=utf-8')
    end

    it 'renders the parking spot template' do
      put api_v1_parking_spot_set_available_url(parking_spot.id)

      expect(response).to render_template('api/v1/parking_spots/_parking_spot')
    end

    it 'sets parking spot unavailable' do
      put api_v1_parking_spot_set_available_url(parking_spot.id)

      parking_spot.reload

      expect(JSON.parse(response.body).deep_symbolize_keys[:unavailable]).to eq(false)
      expect(parking_spot.unavailable?).to eq(false)
      expect(parking_spot.unavailability_reason).to be_nil
    end
  end

  describe 'GET /parking_spots' do
    it 'renders a successful response' do
      get api_v1_parking_spots_url

      expect(response).to have_http_status(200)
    end

    it 'renders JSON' do
      get api_v1_parking_spots_url

      expect(response.content_type).to eq('application/json; charset=utf-8')
    end

    it 'renders the index template' do
      get api_v1_parking_spots_url

      expect(response).to render_template(:index)
    end

    it 'lists parking spots' do
      get api_v1_parking_spots_url

      json = JSON.parse(response.body).deep_symbolize_keys

      expect(json[:parking_spots].size).to eq(1)

      expect(json[:parking_spots][0][:id]).to eq(parking_spot.id)
      expect(json[:parking_spots][0][:number]).to eq(parking_spot.number)
      expect(json[:parking_spots][0][:charger_available]).to eq(parking_spot.charger_available?)
      expect(json[:parking_spots][0][:unavailable]).to eq(parking_spot.unavailable?)
      expect(json[:parking_spots][0][:unavailability_reason]).to be_nil

      # We accept within one second as the database persisted time has less precision than ruby time
      expect(Time.zone.parse(json[:parking_spots][0][:created_at])).to be_within(1.second).of(parking_spot.created_at)
      expect(Time.zone.parse(json[:parking_spots][0][:updated_at])).to be_within(1.second).of(parking_spot.updated_at)
    end

    it 'includes pagination' do
      get api_v1_parking_spots_url

      json = JSON.parse(response.body).deep_symbolize_keys

      expect(json[:total_count]).to eq(1)
      expect(json[:total_pages]).to eq(1)
      expect(json[:current_page]).to eq(1)
      expect(json[:limit_per_page]).to eq(25)
    end
  end

  describe 'GET /parking_spots/{id}' do
    it 'returns not found for non-existing parking spot' do
      get api_v1_parking_spot_url('non-existing-id')

      expect(response).to have_http_status(404)

      errors = JSON.parse(response.body).deep_symbolize_keys[:errors]

      expect(errors[0][:title]).to eq('Could not find parking spot')
    end

    it 'renders a successful response' do
      get api_v1_parking_spot_url(parking_spot.id)

      expect(response).to have_http_status(200)
    end

    it 'renders JSON' do
      get api_v1_parking_spot_url(parking_spot.id)

      expect(response.content_type).to eq('application/json; charset=utf-8')
    end

    it 'renders the show template' do
      get api_v1_parking_spot_url(parking_spot.id)

      expect(response).to render_template(:show)
    end

    it 'shows parking spot' do
      get api_v1_parking_spot_url(parking_spot.id)

      json = JSON.parse(response.body).deep_symbolize_keys

      expect(json[:id]).to eq(parking_spot.id)
      expect(json[:number]).to eq(parking_spot.number)
      expect(json[:charger_available]).to eq(parking_spot.charger_available?)
      expect(json[:unavailable]).to eq(parking_spot.unavailable?)
      expect(json[:unavailability_reason]).to be_nil

      # We accept within one second as the database persisted time has less precision than ruby time
      expect(Time.zone.parse(json[:created_at])).to be_within(1.second).of(parking_spot.created_at)
      expect(Time.zone.parse(json[:updated_at])).to be_within(1.second).of(parking_spot.updated_at)
    end
  end

  describe 'PATCH /parking_spots/{id}' do
    it 'returns not found for non-existing parking spot' do
      patch api_v1_parking_spot_url('non-existing-id')

      expect(response).to have_http_status(404)

      errors = JSON.parse(response.body).deep_symbolize_keys[:errors]

      expect(errors[0][:title]).to eq('Could not find parking spot')
    end

    it 'renders a successful response' do
      patch api_v1_parking_spot_url(parking_spot.id)

      expect(response).to have_http_status(200)
    end

    it 'renders JSON' do
      patch api_v1_parking_spot_url(parking_spot.id)

      expect(response.content_type).to eq('application/json; charset=utf-8')
    end

    it 'renders the parking spot template' do
      patch api_v1_parking_spot_url(parking_spot.id)

      expect(response).to render_template('api/v1/parking_spots/_parking_spot')
    end

    it 'updates parking spot' do
      patch api_v1_parking_spot_url(parking_spot.id), params: {
        number: 5,
        charger_available: true
      }

      parking_spot.reload

      json = JSON.parse(response.body).deep_symbolize_keys

      expect(json[:id]).to eq(parking_spot.id)
      expect(json[:number]).to eq(5)
      expect(json[:charger_available]).to eq(true)
      expect(json[:unavailable]).to eq(parking_spot.unavailable?)
      expect(json[:unavailability_reason]).to be_nil

      # We accept within one second as the database persisted time has less precision than ruby time
      expect(Time.zone.parse(json[:created_at])).to be_within(1.second).of(parking_spot.created_at)
      expect(Time.zone.parse(json[:updated_at])).to be_within(1.second).of(parking_spot.updated_at)
    end

    it 'ignores updating non-permitted parameters' do
      patch api_v1_parking_spot_url(parking_spot.id), params: {
        unavailable: true,
        unavailability_reason: 'Test'
      }

      parking_spot.reload

      json = JSON.parse(response.body).deep_symbolize_keys

      expect(json[:id]).to eq(parking_spot.id)
      expect(json[:number]).to eq(parking_spot.number)
      expect(json[:charger_available]).to eq(parking_spot.charger_available?)
      expect(json[:unavailable]).to eq(false)
      expect(json[:unavailability_reason]).to be_nil

      # We accept within one second as the database persisted time has less precision than ruby time
      expect(Time.zone.parse(json[:created_at])).to be_within(1.second).of(parking_spot.created_at)
      expect(Time.zone.parse(json[:updated_at])).to be_within(1.second).of(parking_spot.updated_at)
    end
  end
end
