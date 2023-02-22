# frozen_string_literal: true

module Api
  module V1
    # Actions for the Vehicle resource
    class VehiclesController < ApiController

      def create
        @vehicle = Vehicle.create!(vehicle_params)

        render @vehicle, status: :created
      end

      def destroy
        @vehicle = Vehicle.find(params[:id])

        @vehicle.destroy!

        render json: {}, status: 204
      end

      def index
        @vehicles = Vehicle.all.page(page_params[:page]).per(page_params[:page_size])
      end

      def show
        @vehicle = Vehicle.find(params[:id])
      end

      def update
        @vehicle = Vehicle.find(params[:id])

        @vehicle.update!(vehicle_params)

        render @vehicle
      end

      def vehicle_params
        params.permit(
          :user_id,
          :ev,
          :license_plate_number,
          :make,
          :model,
          :vehicle_type
        )
      end
    end
  end
end
