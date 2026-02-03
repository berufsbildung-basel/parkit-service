# frozen_string_literal: true

module Api
  module V1
    # Actions for the Vehicle resource
    class VehiclesController < ApiController

      def create
        @vehicle = Vehicle.new(vehicle_params)
        authorize @vehicle
        @vehicle.save!

        render @vehicle, status: :created
      end

      def destroy
        @vehicle = Vehicle.find(params[:id])
        authorize @vehicle

        @vehicle.destroy!

        render json: {}, status: 204
      end

      def index
        @vehicles = policy_scope(Vehicle).page(page_params[:page]).per(page_params[:page_size])
      end

      def show
        @vehicle = Vehicle.find(params[:id])
        authorize @vehicle
      end

      def update
        @vehicle = Vehicle.find(params[:id])
        authorize @vehicle

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
