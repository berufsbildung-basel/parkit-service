# frozen_string_literal: true

module Api
  module V1
    # Actions for the Reservation resource
    class ReservationsController < ApiController

      rescue_from ActiveRecord::RecordNotFound do |e|
        render_json_error :not_found, :reservation_not_found
      end

      def create
        return unless validate_request_parameters(reservation_params)

        @reservation = Reservation.create(reservation_params)

        return render_validation_errors(@reservation) unless @reservation.save

        render @reservation, status: :created
      end

      def destroy
        # Reservations cannot be deleted
        render_json_error :method_not_allowed, :reservation_cannot_be_removed
      end

      def cancel
        @reservation = Reservation.find(params[:reservation_id])
        # TODO: set cancelled_by to logged in user
        @reservation.update(cancelled: true, cancelled_at: DateTime.now, cancelled_by: 'User')
        @reservation.save(validate: false)
      end

      def index
        @reservations = Reservation.all.page(page_params[:page]).per(page_params[:page_size])
      end

      def show
        @reservation = Reservation.find(params[:id])
      end

      def update
        @reservation = Reservation.find(params[:id])

        return render_validation_errors(@reservation) unless @reservation.update(reservation_params)

        render @reservation
      end

      private

      def validate_request_parameters(reservation_params)
        unless reservation_params[:parking_spot_id].present?
          render_json_error :bad_request, :parking_spot_id_required
          return false
        end

        unless reservation_params[:user_id].present?
          render_json_error :bad_request, :user_id_required
          return false
        end

        unless reservation_params[:vehicle_id].present?
          render_json_error :bad_request, :vehicle_id_required
          return false
        end

        true
      end

      def render_validation_errors(reservation)
        if has_error?(reservation, :parking_spot, :blank)
          render_json_error :not_found, :parking_spot_not_found
          return
        end

        if has_error?(reservation, :user, :blank)
          render_json_error :not_found, :user_not_found
          return
        end

        if has_error?(reservation, :vehicle, :blank)
          render_json_error :not_found, :vehicle_not_found
          return
        end

        if has_error?(reservation, :base, :overlaps_with_existing_reservation)
          render_json_error :conflict, :reservation_is_overlapping
        end
      end

      def reservation_params
        params.permit(
          :parking_spot_id,
          :user_id,
          :vehicle_id,
          :user_id,
          :date,
          :half_day,
          :am
        )
      end
    end
  end
end
