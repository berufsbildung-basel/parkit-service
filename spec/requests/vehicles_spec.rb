# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Vehicles Requests', type: :request do
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

  describe 'POST /vehicles' do
    it 'renders a successful response' do
      post api_v1_vehicles_url, params: {
        license_plate_number: Faker::Vehicle.unique.license_plate,
        make: Faker::Vehicle.make,
        model: Faker::Vehicle.model,
        user_id: user.id
      }

      expect(response).to have_http_status(201)
    end

    it 'renders JSON' do
      post api_v1_vehicles_url, params: {
        license_plate_number: Faker::Vehicle.unique.license_plate,
        make: Faker::Vehicle.make,
        model: Faker::Vehicle.model,
        user_id: user.id
      }

      expect(response.content_type).to eq('application/json; charset=utf-8')
    end

    it 'renders the vehicle template' do
      post api_v1_vehicles_url, params: {
        license_plate_number: Faker::Vehicle.unique.license_plate,
        make: Faker::Vehicle.make,
        model: Faker::Vehicle.model,
        user_id: user.id
      }

      expect(response).to render_template('api/v1/vehicles/_vehicle')
    end

    it 'creates a new vehicle' do
      post api_v1_vehicles_url, params: {
        license_plate_number: Faker::Vehicle.unique.license_plate,
        make: Faker::Vehicle.make,
        model: Faker::Vehicle.model,
        user_id: user.id,
        ev: true
      }

      expect(response).to have_http_status(201)

      new_vehicle = Vehicle.last
      json = JSON.parse(response.body).deep_symbolize_keys

      expect(json[:id]).to eq(new_vehicle.id)
      expect(json[:license_plate_number]).to eq(new_vehicle.license_plate_number)
      expect(json[:make]).to eq(new_vehicle.make)
      expect(json[:model]).to eq(new_vehicle.model)
      expect(json[:user_id]).to eq(new_vehicle.user.id)
      expect(json[:ev]).to eq(new_vehicle.ev?)
      expect(json[:vehicle_type]).to eq(new_vehicle.vehicle_type)

      # We accept within one second as the database persisted time has less precision than ruby time
      expect(Time.zone.parse(json[:created_at])).to be_within(1.second).of(new_vehicle.created_at)
      expect(Time.zone.parse(json[:updated_at])).to be_within(1.second).of(new_vehicle.updated_at)
    end
  end

  describe 'DELETE /vehicles/{id}' do
    it 'renders a successful response' do
      delete api_v1_vehicle_url(vehicle.id)

      expect(response).to have_http_status(204)
    end

    it 'renders without content type' do
      delete api_v1_vehicle_url(vehicle.id)

      expect(response.content_type).to eq(nil)
    end

    it 'has no content' do
      delete api_v1_vehicle_url(vehicle.id)

      expect(response.body).to eq('')
    end

    it 'deletes a vehicle' do
      expect(Vehicle.all.size).to eq(1)

      delete api_v1_vehicle_url(vehicle.id)

      expect(Vehicle.all.size).to eq(0)
    end
  end

  describe 'GET /vehicles' do
    it 'renders a successful response' do
      get api_v1_vehicles_url

      expect(response).to have_http_status(200)
    end

    it 'renders JSON' do
      get api_v1_vehicles_url

      expect(response.content_type).to eq('application/json; charset=utf-8')
    end

    it 'renders the index template' do
      get api_v1_vehicles_url

      expect(response).to render_template(:index)
    end

    it 'lists vehicles' do
      get api_v1_vehicles_url

      json = JSON.parse(response.body).deep_symbolize_keys

      expect(json[:vehicles].size).to eq(1)

      expect(json[:vehicles][0][:id]).to eq(vehicle.id)
      expect(json[:vehicles][0][:license_plate_number]).to eq(vehicle.license_plate_number)
      expect(json[:vehicles][0][:make]).to eq(vehicle.make)
      expect(json[:vehicles][0][:model]).to eq(vehicle.model)
      expect(json[:vehicles][0][:ev]).to eq(vehicle.ev?)
      expect(json[:vehicles][0][:user_id]).to eq(vehicle.user.id)
      expect(json[:vehicles][0][:vehicle_type]).to eq(vehicle.vehicle_type)

      # We accept within one second as the database persisted time has less precision than ruby time
      expect(Time.zone.parse(json[:vehicles][0][:created_at])).to be_within(1.second).of(vehicle.created_at)
      expect(Time.zone.parse(json[:vehicles][0][:updated_at])).to be_within(1.second).of(vehicle.updated_at)
    end

    it 'includes pagination' do
      get api_v1_vehicles_url

      json = JSON.parse(response.body).deep_symbolize_keys

      expect(json[:total_count]).to eq(1)
      expect(json[:total_pages]).to eq(1)
      expect(json[:current_page]).to eq(1)
      expect(json[:limit_per_page]).to eq(25)
    end
  end

  describe 'GET /vehicles/{id}' do
    it 'returns not found for non-existing vehicle' do
      expect do
        get api_v1_vehicle_url('non-existing-id')
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'renders a successful response' do
      get api_v1_vehicle_url(vehicle.id)

      expect(response).to have_http_status(200)
    end

    it 'renders JSON' do
      get api_v1_vehicle_url(vehicle.id)

      expect(response.content_type).to eq('application/json; charset=utf-8')
    end

    it 'renders the show template' do
      get api_v1_vehicle_url(vehicle.id)

      expect(response).to render_template(:show)
    end

    it 'shows vehicle' do
      get api_v1_vehicle_url(vehicle.id)

      json = JSON.parse(response.body).deep_symbolize_keys

      expect(json[:id]).to eq(vehicle.id)
      expect(json[:license_plate_number]).to eq(vehicle.license_plate_number)
      expect(json[:make]).to eq(vehicle.make)
      expect(json[:model]).to eq(vehicle.model)
      expect(json[:ev]).to eq(vehicle.ev?)
      expect(json[:user_id]).to eq(vehicle.user.id)
      expect(json[:vehicle_type]).to eq(vehicle.vehicle_type)

      # We accept within one second as the database persisted time has less precision than ruby time
      expect(Time.zone.parse(json[:created_at])).to be_within(1.second).of(vehicle.created_at)
      expect(Time.zone.parse(json[:updated_at])).to be_within(1.second).of(vehicle.updated_at)
    end
  end

  describe 'PATCH /vehicles/{id}' do
    it 'returns not found for non-existing vehicle' do
      expect do
        patch api_v1_vehicle_url('non-existing-id')
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'renders a successful response' do
      patch api_v1_vehicle_url(vehicle.id)

      expect(response).to have_http_status(200)
    end

    it 'renders JSON' do
      patch api_v1_vehicle_url(vehicle.id)

      expect(response.content_type).to eq('application/json; charset=utf-8')
    end

    it 'renders the vehicle template' do
      patch api_v1_vehicle_url(vehicle.id)

      expect(response).to render_template('api/v1/vehicles/_vehicle')
    end

    it 'updates vehicle' do
      patch api_v1_vehicle_url(vehicle.id), params: {
        make: 'New-Make',
        ev: true,
        vehicle_type: 'motorcycle'
      }

      vehicle.reload

      json = JSON.parse(response.body).deep_symbolize_keys

      expect(json[:id]).to eq(vehicle.id)
      expect(json[:license_plate_number]).to eq(vehicle.license_plate_number)
      expect(json[:make]).to eq('New-Make')
      expect(json[:model]).to eq(vehicle.model)
      expect(json[:ev]).to eq(true)
      expect(json[:user_id]).to eq(vehicle.user.id)
      expect(json[:vehicle_type]).to eq('motorcycle')

      # We accept within one second as the database persisted time has less precision than ruby time
      expect(Time.zone.parse(json[:created_at])).to be_within(1.second).of(vehicle.created_at)
      expect(Time.zone.parse(json[:updated_at])).to be_within(1.second).of(vehicle.updated_at)
    end
  end
end
