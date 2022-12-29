# frozen_string_literal: true

module Api
  module V1
    # Actions for the ParkingSpot resource
    class ParkingSpotsController < ApiController

      rescue_from ActiveRecord::RecordNotFound do |e|
        render_json_error :not_found, :parking_spot_not_found
      end

      # Returns available parking spots for a given date, user and vehicle
      def check_availability
        check = AvailabilityCheckRequest.new(check_availability_params)

        return render_validation_errors(check) unless check.valid?

        @parking_spots = ParkingSpot.available_on_date_and_time_for_vehicle_type(
          check.date,
          check.vehicle,
          check.half_day?,
          check.am?
        )
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

      private

      def render_validation_errors(check)
        if has_error?(check, :parking_spot_id, :blank)
          render_json_error :bad_request, :parking_spot_id_required
          return
        end

        if has_error?(check, :vehicle_id, :blank)
          render_json_error :bad_request, :vehicle_id_required
          return
        end

        if has_error?(check, :date, :invalid_date)
          render_json_error :bad_request, :invalid_date
          return
        end

        if has_error?(check, :date, :must_be_on_or_after_today)
          render_json_error :bad_request, :date_must_be_on_or_after_today
          return
        end

        if has_error?(check, :date, :exceeds_max_weeks_into_the_future)
          render_json_error :bad_request, :date_exceeds_max_weeks_into_the_future
          return
        end

        if has_error?(check, :vehicle, :blank)
          render_json_error :not_found, :vehicle_not_found
          return
        end

        if has_error?(check, :user, :marked_disabled)
          render_json_error :forbidden, :user_is_disabled
          return
        end

        if has_error?(check, :user, :exceeds_max_reservations_per_day)
          render_json_error :forbidden, :user_exceeds_max_reservations_per_day
          return
        end

        if has_error?(check, :user, :exceeds_max_reservations_per_week)
          render_json_error :forbidden, :user_exceeds_max_reservations_per_week
          return
        end

        render_json_error :bad_request, :validation_error
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
