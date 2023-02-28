# frozen_string_literal: true

# Vehicle controller
class ReservationsController < ApplicationController
  def create
    params[:reservations].each do |reservation|
      @reservation = Reservation.create(reservation_params(reservation))
      authorize @reservation
      unless @reservation.save
        respond_to do |format|
          flash[:danger] = 'There was a problem creating the reservations.'
          format.html { redirect_to dashboard_path }
        end
        return
      end
    end

    respond_to do |format|
      flash[:success] = 'Reservations were successfully created.'
      format.html { redirect_to dashboard_path }
    end

  end

  def index
    @vehicles = policy_scope(Vehicle.all.order(:license_plate_number))
  end

  def new
    @user = User.find(params[:user_id])
    @vehicle = @user.vehicles.find(params[:vehicle_id])
    @reservation = @vehicle.reservations.new
    @parking_spots = ParkingSpot.status_for_user_next_days(@user, ParkitService::RESERVATION_MAX_WEEKS_INTO_THE_FUTURE * 7)
    authorize @reservation
  end

  def show
    @vehicle = Vehicle.find(params[:id])
    authorize @vehicle
  end

  def update
    @vehicle = Vehicle.find(params[:id])
    authorize @vehicle

    if @vehicle.update(vehicle_params)
      respond_to do |format|
        flash[:success] = 'Vehicle was successfully updated.'
        format.html { redirect_to vehicle_path(@vehicle.id) }
      end
    else
      respond_to do |format|
        flash[:danger] = 'There was a problem updating the vehicle.'
        format.html { render :edit }
      end
    end
  end

  def cancel
    # code here
  end

  private

  def reservation_params(params)
    params.require(:reservation).permit(
      :date,
      :am,
      :half_day,
      :user_id,
      :parking_spot_id,
      :vehicle_id
    )
  end
end
