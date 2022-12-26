# frozen_string_literal: true

module Api
  module V1
    # Actions for the ParkingSpot resource
    class ParkingSpotsController < ApiController
      def create

      end

      def set_unavailable
        @parking_spot = ParkingSpot.find(params[:parking_spot_id])
        @parking_spot.unavailable = true
        @parking_spot.save!
      end

      def set_available
        @parking_spot = ParkingSpot.find(params[:parking_spot_id])
        @parking_spot.unavailable = false
        @parking_spot.save!
      end

      def index
        @parking_spots = ParkingSpot.all.page(page_params[:page]).per(page_params[:page_size])
      end

      def show
        @parking_spot = ParkingSpot.find(params[:id])
      end

      def update
        @parking_spot = ParkingSpot.find(params[:id])

        @parking_spot.update!(parking_spot_params)

        render @parking_spot
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
