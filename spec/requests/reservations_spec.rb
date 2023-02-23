# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Reservations Requests', type: :request do
  let!(:parking_spot) do
    ParkingSpot.create({ number: 2 })
  end

  let!(:user) do
    User.create!({
                   username: Faker::Internet.username,
                   email: Faker::Internet.email,
                   first_name: Faker::Name.first_name,
                   last_name: Faker::Name.last_name
                 })
  end

  let!(:vehicle) do
    Vehicle.create!({
                      license_plate_number: Faker::Vehicle.unique.license_plate,
                      make: Faker::Vehicle.make,
                      model: Faker::Vehicle.model,
                      user:
                    })
  end

  let!(:user2) do
    User.create!({
                   username: Faker::Internet.username,
                   email: Faker::Internet.email,
                   first_name: Faker::Name.first_name,
                   last_name: Faker::Name.last_name
                 })
  end

  let!(:vehicle2) do
    Vehicle.create!({
                      license_plate_number: Faker::Vehicle.unique.license_plate,
                      make: Faker::Vehicle.make,
                      model: Faker::Vehicle.model,
                      user: user2
                    })
  end

  reservation_date = Date.today

  describe 'POST /reservations' do
    it 'rejects request without parking_spot_id' do
      post api_v1_reservations_url

      expect(response).to have_http_status(400)

      errors = JSON.parse(response.body).deep_symbolize_keys[:errors]

      expect(errors[0][:title]).to eq('The parameter \'parking_spot_id\' is required')
    end

    it 'rejects request without user_id' do
      post api_v1_reservations_url, params: {
        parking_spot_id: parking_spot.id
      }

      expect(response).to have_http_status(400)

      errors = JSON.parse(response.body).deep_symbolize_keys[:errors]

      expect(errors[0][:title]).to eq('The parameter \'user_id\' is required')
    end

    it 'rejects request without vehicle_id' do
      post api_v1_reservations_url, params: {
        parking_spot_id: parking_spot.id,
        user_id: user.id
      }

      expect(response).to have_http_status(400)

      errors = JSON.parse(response.body).deep_symbolize_keys[:errors]

      expect(errors[0][:title]).to eq('The parameter \'vehicle_id\' is required')
    end

    it 'rejects request with non-existing parking spot' do
      post api_v1_reservations_url, params: {
        parking_spot_id: 'does-not-exist',
        user_id: user.id,
        vehicle_id: vehicle.id,
        date: reservation_date
      }

      expect(response).to have_http_status(404)

      errors = JSON.parse(response.body).deep_symbolize_keys[:errors]

      expect(errors[0][:title]).to eq('Could not find parking spot')
    end

    it 'rejects request with non-existing user' do
      post api_v1_reservations_url, params: {
        parking_spot_id: parking_spot.id,
        user_id: 'does-not-exist',
        vehicle_id: vehicle.id,
        date: reservation_date
      }

      errors = JSON.parse(response.body).deep_symbolize_keys[:errors]

      expect(errors[0][:title]).to eq('Could not find user')
    end

    it 'rejects request with non-existing vehicle' do
      post api_v1_reservations_url, params: {
        parking_spot_id: parking_spot.id,
        user_id: user.id,
        vehicle_id: 'does-not-exist',
        date: reservation_date
      }

      errors = JSON.parse(response.body).deep_symbolize_keys[:errors]

      expect(errors[0][:title]).to eq('Could not find vehicle')
    end

    it 'rejects request for overlapping reservation' do
      Reservation.create!({
                            date: reservation_date,
                            vehicle:,
                            parking_spot:,
                            user:,
                            half_day: false,
                            am: false
                          })

      post api_v1_reservations_url, params: {
        parking_spot_id: parking_spot.id,
        user_id: user2.id,
        vehicle_id: vehicle2.id,
        date: reservation_date
      }

      expect(response).to have_http_status(409)

      errors = JSON.parse(response.body).deep_symbolize_keys[:errors]

      expect(errors[0][:title]).to eq('Reservation is overlapping with another')
    end

    it 'renders a successful response' do
      post api_v1_reservations_url, params: {
        parking_spot_id: parking_spot.id,
        user_id: user.id,
        vehicle_id: vehicle.id,
        date: reservation_date
      }

      expect(response).to have_http_status(201)
    end

    it 'renders JSON' do
      post api_v1_reservations_url, params: {
        parking_spot_id: parking_spot.id,
        user_id: user.id,
        vehicle_id: vehicle.id,
        date: reservation_date
      }

      expect(response.content_type).to eq('application/json; charset=utf-8')
    end

    it 'renders the reservation template' do
      post api_v1_reservations_url, params: {
        parking_spot_id: parking_spot.id,
        user_id: user.id,
        vehicle_id: vehicle.id,
        date: reservation_date
      }

      expect(response).to render_template('api/v1/reservations/_reservation')
    end

    it 'creates a new reservation' do
      post api_v1_reservations_url, params: {
        parking_spot_id: parking_spot.id,
        user_id: user.id,
        vehicle_id: vehicle.id,
        date: reservation_date
      }

      expect(response).to have_http_status(201)

      new_reservation = Reservation.last
      json = JSON.parse(response.body).deep_symbolize_keys

      expect(json[:id]).to eq(new_reservation.id)
      expect(json[:parking_spot_id]).to eq(new_reservation.parking_spot.id)
      expect(json[:user_id]).to eq(new_reservation.user.id)
      expect(json[:vehicle_id]).to eq(new_reservation.vehicle.id)
      expect(json[:date]).to eq(reservation_date.to_s)
      expect(json[:half_day]).to eq(false)
      expect(json[:am]).to eq(false)

      # We accept within one second as the database persisted time has less precision than ruby time
      expect(Time.zone.parse(json[:start_time])).to be_within(1.second).of(
        Reservation.calculate_start_time(reservation_date, false, false)
      )
      expect(Time.zone.parse(json[:end_time])).to be_within(1.second).of(
        Reservation.calculate_end_time(reservation_date, false, false)
      )
      expect(Time.zone.parse(json[:created_at])).to be_within(1.second).of(new_reservation.created_at)
      expect(Time.zone.parse(json[:updated_at])).to be_within(1.second).of(new_reservation.updated_at)
    end
  end

  describe 'DELETE /reservations/{id}' do
    it 'rejects deleting a reservation' do
      delete api_v1_reservation_url('some-id')

      expect(response).to have_http_status(405)

      errors = JSON.parse(response.body).deep_symbolize_keys[:errors]

      expect(errors[0][:title]).to eq('Could not remove reservation')
    end
  end

  describe 'PUT /reservations/{id}/cancel' do
    reservation = nil

    before(:each) do
      reservation = Reservation.create!({
                                          date: reservation_date,
                                          vehicle:,
                                          parking_spot:,
                                          user:,
                                          half_day: false,
                                          am: false
                                        })
    end

    it 'renders a successful response' do
      put api_v1_reservation_cancel_url(reservation.id)

      expect(response).to have_http_status(200)
    end

    it 'renders JSON' do
      put api_v1_reservation_cancel_url(reservation.id)

      expect(response.content_type).to eq('application/json; charset=utf-8')
    end

    it 'renders the reservation template' do
      put api_v1_reservation_cancel_url(reservation.id)

      expect(response).to render_template('api/v1/reservations/_reservation')
    end

    it 'cancels a reservation' do
      put api_v1_reservation_cancel_url(reservation.id)

      reservation.reload

      json = JSON.parse(response.body).deep_symbolize_keys

      expect(reservation.cancelled?).to eq(true)
      expect(reservation.cancelled_by).to eq('User')

      expect(json[:cancelled_by]).to eq('User')
      expect(Time.zone.parse(json[:cancelled_at])).to be_within(1.second).of(reservation.cancelled_at)

      expect(json[:id]).to eq(reservation.id)
      expect(json[:parking_spot_id]).to eq(reservation.parking_spot.id)
      expect(json[:user_id]).to eq(reservation.user.id)
      expect(json[:vehicle_id]).to eq(reservation.vehicle.id)
      expect(json[:date]).to eq(reservation_date.to_s)
      expect(json[:half_day]).to eq(reservation.half_day?)
      expect(json[:am]).to eq(reservation.am?)

      # We accept within one second as the database persisted time has less precision than ruby time
      expect(Time.zone.parse(json[:start_time])).to be_within(1.second).of(
        Reservation.calculate_start_time(reservation_date, false, false)
      )
      expect(Time.zone.parse(json[:end_time])).to be_within(1.second).of(
        Reservation.calculate_end_time(reservation_date, false, false)
      )
      expect(Time.zone.parse(json[:created_at])).to be_within(1.second).of(reservation.created_at)
      expect(Time.zone.parse(json[:updated_at])).to be_within(1.second).of(reservation.updated_at)
    end
  end

  describe 'GET /reservations' do
    reservation = nil

    before(:each) do
      reservation = Reservation.create!({
                                          date: reservation_date,
                                          vehicle:,
                                          parking_spot:,
                                          user:,
                                          half_day: false,
                                          am: false
                                        })
    end

    it 'renders a successful response' do
      get api_v1_reservations_url

      expect(response).to have_http_status(200)
    end

    it 'renders JSON' do
      get api_v1_reservations_url

      expect(response.content_type).to eq('application/json; charset=utf-8')
    end

    it 'renders the index template' do
      get api_v1_reservations_url

      expect(response).to render_template(:index)
    end

    it 'lists reservations' do
      get api_v1_reservations_url

      json = JSON.parse(response.body).deep_symbolize_keys

      expect(json[:reservations].size).to eq(1)

      expect(json[:reservations][0][:id]).to eq(reservation.id)
      expect(json[:reservations][0][:parking_spot_id]).to eq(reservation.parking_spot.id)
      expect(json[:reservations][0][:user_id]).to eq(reservation.user.id)
      expect(json[:reservations][0][:vehicle_id]).to eq(reservation.vehicle.id)
      expect(json[:reservations][0][:date]).to eq(reservation_date.to_s)
      expect(json[:reservations][0][:half_day]).to eq(false)
      expect(json[:reservations][0][:am]).to eq(false)

      # We accept within one second as the database persisted time has less precision than ruby time
      expect(Time.zone.parse(json[:reservations][0][:start_time])).to be_within(1.second).of(
        Reservation.calculate_start_time(reservation_date, false, false)
      )
      expect(Time.zone.parse(json[:reservations][0][:end_time])).to be_within(1.second).of(
        Reservation.calculate_end_time(reservation_date, false, false)
      )
      expect(Time.zone.parse(json[:reservations][0][:created_at])).to be_within(1.second).of(reservation.created_at)
      expect(Time.zone.parse(json[:reservations][0][:updated_at])).to be_within(1.second).of(reservation.updated_at)
    end

    it 'includes pagination' do
      get api_v1_reservations_url

      json = JSON.parse(response.body).deep_symbolize_keys

      expect(json[:total_count]).to eq(1)
      expect(json[:total_pages]).to eq(1)
      expect(json[:current_page]).to eq(1)
      expect(json[:limit_per_page]).to eq(25)
    end
  end

  describe 'GET /reservations/{id}' do
    reservation = nil

    before(:each) do
      reservation = Reservation.create!({
                                          date: reservation_date,
                                          vehicle:,
                                          parking_spot:,
                                          user:,
                                          half_day: false,
                                          am: false
                                        })
    end

    it 'returns not found for non-existing reservation' do
      get api_v1_reservation_url('non-existing-id')

      expect(response).to have_http_status(404)

      errors = JSON.parse(response.body).deep_symbolize_keys[:errors]

      expect(errors[0][:title]).to eq('Could not find reservation')
    end

    it 'renders a successful response' do
      get api_v1_reservation_url(reservation.id)

      expect(response).to have_http_status(200)
    end

    it 'renders JSON' do
      get api_v1_reservation_url(reservation.id)

      expect(response.content_type).to eq('application/json; charset=utf-8')
    end

    it 'renders the show template' do
      get api_v1_reservation_url(reservation.id)

      expect(response).to render_template(:show)
    end

    it 'shows reservation' do
      get api_v1_reservation_url(reservation.id)

      json = JSON.parse(response.body).deep_symbolize_keys

      expect(json[:id]).to eq(reservation.id)
      expect(json[:parking_spot_id]).to eq(reservation.parking_spot.id)
      expect(json[:user_id]).to eq(reservation.user.id)
      expect(json[:vehicle_id]).to eq(reservation.vehicle.id)
      expect(json[:date]).to eq(reservation_date.to_s)
      expect(json[:half_day]).to eq(reservation.half_day?)
      expect(json[:am]).to eq(reservation.am?)

      # We accept within one second as the database persisted time has less precision than ruby time
      expect(Time.zone.parse(json[:start_time])).to be_within(1.second).of(
        Reservation.calculate_start_time(reservation_date, false, false)
      )
      expect(Time.zone.parse(json[:end_time])).to be_within(1.second).of(
        Reservation.calculate_end_time(reservation_date, false, false)
      )
      expect(Time.zone.parse(json[:created_at])).to be_within(1.second).of(reservation.created_at)
      expect(Time.zone.parse(json[:updated_at])).to be_within(1.second).of(reservation.updated_at)
    end
  end

  describe 'PATCH /reservations/{id}' do
    reservation = nil

    before(:each) do
      reservation = Reservation.create!({
                                          date: reservation_date,
                                          vehicle:,
                                          parking_spot:,
                                          user:,
                                          half_day: false,
                                          am: false
                                        })
    end

    it 'returns not found for non-existing reservation' do
      patch api_v1_reservation_url('non-existing-id')

      expect(response).to have_http_status(404)

      errors = JSON.parse(response.body).deep_symbolize_keys[:errors]

      expect(errors[0][:title]).to eq('Could not find reservation')
    end

    it 'renders a successful response' do
      patch api_v1_reservation_url(reservation.id)

      expect(response).to have_http_status(200)
    end

    it 'renders JSON' do
      patch api_v1_reservation_url(reservation.id)

      expect(response.content_type).to eq('application/json; charset=utf-8')
    end

    it 'renders the reservation template' do
      patch api_v1_reservation_url(reservation.id)

      expect(response).to render_template('api/v1/reservations/_reservation')
    end

    it 'updates reservation' do
      updated_reservation_date = reservation_date + 1.week

      patch api_v1_reservation_url(reservation.id), params: {
        date: updated_reservation_date,
        half_day: true,
        am: true
      }

      reservation.reload

      json = JSON.parse(response.body).deep_symbolize_keys

      expect(json[:id]).to eq(reservation.id)
      expect(json[:parking_spot_id]).to eq(reservation.parking_spot.id)
      expect(json[:user_id]).to eq(reservation.user.id)
      expect(json[:vehicle_id]).to eq(reservation.vehicle.id)
      expect(json[:date]).to eq(updated_reservation_date.to_s)
      expect(json[:half_day]).to eq(true)
      expect(json[:am]).to eq(true)

      # We accept within one second as the database persisted time has less precision than ruby time
      expect(Time.zone.parse(json[:start_time])).to be_within(1.second).of(
        Reservation.calculate_start_time(updated_reservation_date, true, true)
      )
      expect(Time.zone.parse(json[:end_time])).to be_within(1.second).of(
        Reservation.calculate_end_time(updated_reservation_date, true, true)
      )
      expect(Time.zone.parse(json[:created_at])).to be_within(1.second).of(reservation.created_at)
      expect(Time.zone.parse(json[:updated_at])).to be_within(1.second).of(reservation.updated_at)
    end
  end
end
