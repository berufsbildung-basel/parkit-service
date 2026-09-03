# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ReservationsController (HTML)', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:facilities_user) do
    User.create!(username: 'facilities-user', email: 'facilities@example.com', first_name: 'Facilities',
                 last_name: 'User', role: :facilities)
  end
  let(:regular_user) do
    User.create!(username: 'regular-user', email: 'user@example.com', first_name: 'Regular', last_name: 'User')
  end
  let!(:vehicle) { Vehicle.create!(license_plate_number: 'ZH 1', make: 'VW', model: 'Golf', user: regular_user) }
  let!(:parking_spot) { ParkingSpot.create!(number: 50) }

  before { allow(SlackHelper).to receive(:send_message) }

  describe 'POST /reservations (guest)' do
    before { sign_in facilities_user }

    it 'creates a GuestReservation and does not raise building the Slack notification' do
      post reservations_path, params: {
        reservations: [
          { reservation: { date: Date.today, parking_spot_id: parking_spot.id,
                            guest_name: 'Jane Guest', guest_license_plate: 'ZH 9999' } }
        ]
      }

      expect(response).to redirect_to(dashboard_path)
      expect(GuestReservation.count).to eq(1)
      expect(GuestReservation.last.guest_name).to eq('Jane Guest')
      expect(GuestReservation.last.created_by).to eq(facilities_user)
      expect(SlackHelper).to have_received(:send_message).with(a_string_including('Jane Guest'))
    end

    it 'redirects back to the guest form, not a UrlGenerationError, when the parking spot no longer exists' do
      post reservations_path, params: {
        reservations: [
          { reservation: { date: Date.today, parking_spot_id: 'does-not-exist',
                            guest_name: 'Jane Guest', guest_license_plate: 'ZH 9999' } }
        ]
      }

      expect(response).to redirect_to(new_guest_reservations_path)
      expect(GuestReservation.count).to eq(0)
    end

    it 'allows a second guest reservation on the same day (bypasses the per-day cap)' do
      second_spot = ParkingSpot.create!(number: 51)

      post reservations_path, params: {
        reservations: [
          { reservation: { date: Date.today, parking_spot_id: parking_spot.id,
                            guest_name: 'Guest One', guest_license_plate: 'G1' } }
        ]
      }
      post reservations_path, params: {
        reservations: [
          { reservation: { date: Date.today, parking_spot_id: second_spot.id,
                            guest_name: 'Guest Two', guest_license_plate: 'G2' } }
        ]
      }

      expect(GuestReservation.count).to eq(2)
    end
  end

  describe 'POST /reservations (registered user, regression)' do
    before { sign_in regular_user }

    it 'still creates a normal Reservation with created_by left nil when booking for themselves' do
      post reservations_path, params: {
        reservations: [
          { reservation: { date: Date.today, parking_spot_id: parking_spot.id,
                            user_id: regular_user.id, vehicle_id: vehicle.id } }
        ]
      }

      expect(Reservation.count).to eq(1)
      expect(Reservation.last).not_to be_a(GuestReservation)
      expect(Reservation.last.created_by).to be_nil
      expect(SlackHelper).to have_received(:send_message).with(a_string_including(regular_user.full_name))
    end
  end

  describe 'GET /reservations/new_guest' do
    it 'is reachable by facilities' do
      sign_in facilities_user
      get new_guest_reservations_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Guest name')
    end

    it 'is reachable by admin' do
      admin = User.create!(username: 'admin-user', email: 'admin@example.com', first_name: 'Admin',
                            last_name: 'User', role: :admin)
      sign_in admin
      get new_guest_reservations_path

      expect(response).to have_http_status(:success)
    end

    it 'forbids a regular user' do
      sign_in regular_user
      get new_guest_reservations_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe 'PUT /reservations/:id/cancel' do
    let!(:guest_reservation) do
      GuestReservation.create!(parking_spot:, date: Date.today, guest_name: 'Guest', guest_license_plate: 'G1')
    end

    it 'cancels a guest reservation when called by facilities' do
      sign_in facilities_user
      put cancel_reservation_path(guest_reservation.id)

      expect(guest_reservation.reload.cancelled?).to eql(true)
      expect(SlackHelper).to have_received(:send_message).with(a_string_including('guest: Guest'))
    end

    it 'forbids a regular user' do
      sign_in regular_user
      put cancel_reservation_path(guest_reservation.id)
      expect(response).to redirect_to(root_path)
    end
  end

  describe 'GET /reservations (index renders guest rows)' do
    let!(:guest_reservation) do
      GuestReservation.create!(parking_spot:, date: Date.today, guest_name: 'Jane Guest', guest_license_plate: 'ZH 9999')
    end

    it 'renders the index without raising, showing the guest name and plate' do
      sign_in facilities_user

      get reservations_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Jane Guest')
      expect(response.body).to include('ZH 9999')
    end
  end

  describe 'PUT /users/:user_id/reservations/:reservation_id/cancel (regression)' do
    let!(:member_reservation) do
      # Future date: can_be_cancelled? denies same-day cancellation to non-privileged users once
      # start_time (beginning of day) has passed, which is always true by the time this test runs.
      Reservation.create!(parking_spot:, vehicle:, user: regular_user, date: Date.tomorrow)
    end

    it 'still cancels a registered user\'s own reservation via the nested route' do
      sign_in regular_user
      put user_reservation_cancel_path(regular_user.id, member_reservation.id)

      expect(member_reservation.reload.cancelled?).to eql(true)
    end
  end
end
