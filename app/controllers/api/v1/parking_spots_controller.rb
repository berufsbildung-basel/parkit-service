# frozen_string_literal: true

module Api
  module V1
    # Actions for the ParkingSpot resource
    class ParkingSpotsController < ApiController
      # Returns available parking spots for a given date, user and vehicle
      def check_availability
        check = AvailabilityCheckRequest.new(check_availability_params)

        begin
          check.valid?
          @parking_spots = ParkingSpot.available_on_date_and_time_for_vehicle_type(
            Date.parse(check.date), check.vehicle, check.half_day?, check.am?
          )
        rescue ActiveModel::StrictValidationFailed => e
          render json: { error: e }, status: 400
        rescue AvailabilityCheckRequest::InvalidDateError => e
          render json: { error: e }, status: 400
        rescue AvailabilityCheckRequest::VehicleNotFoundError => e
          render json: { error: e.message }, status: 404
        rescue AvailabilityCheckRequest::UserDisabledError => e
          render json: { error: e.message }, status: 403
        rescue AvailabilityCheckRequest::UserExceedsReservationsPerDayError => e
          render json: { error: e.message }, status: 403
        rescue AvailabilityCheckRequest::UserExceedsReservationsPerWeekError => e
          render json: { error: e.message }, status: 403
        end
      end

      def create
        @parking_spot = ParkingSpot.create!(parking_spot_params)

        render @parking_spot, status: :created
      end

      def destroy
        @parking_spot = ParkingSpot.find(params[:id])

        @parking_spot.destroy!

        render json: {}, status: 204
      end

      def set_unavailable
        @parking_spot = ParkingSpot.find(params[:parking_spot_id])
        @parking_spot.unavailable = true
        @parking_spot.update!(unavailable_params)
      end

      def set_available
        @parking_spot = ParkingSpot.find(params[:parking_spot_id])
        @parking_spot.unavailable = false
        @parking_spot.unavailability_reason = nil
        @parking_spot.save!
      end

      def index
        @parking_spots = ParkingSpot.all.page(page_params[:page]).per(page_params[:page_size])
      end

      def show
        @parking_spot = ParkingSpot.find(params[:id])
      end

      # List parking spots and any reservations + vehicles on today's date
      def today
        @parking_spots = ParkingSpot.with_reservations_on_date(Date.today)
      end

      def update
        @parking_spot = ParkingSpot.find(params[:id])

        @parking_spot.update!(parking_spot_params)

        render @parking_spot
      end

      def check_availability_params
        params.permit(
          :date,
          :vehicle_id,
          :half_day,
          :am
        )
      end

      def parking_spot_params
        params.permit(
          :number,
          :charger_available
        )
      end

      def unavailable_params
        params.permit(
          :unavailability_reason
        )
      end
    end
  end
end
