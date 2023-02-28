# frozen_string_literal: true

# Vehicle controller
class ReservationsController < ApplicationController
  def create
    params[:reservations].each do |reservation|
      @reservation = Reservation.new(reservation_params(reservation))
      authorize @reservation
      unless @reservation.save
        respond_to do |format|
          flash[:danger] =
            "There was a problem creating the reservations: #{@reservation.errors.full_messages.join(';')}"
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
    @reservations = policy_scope(
      Reservation.joins(:parking_spot)
                 .where('reservations.date >= ?', Date.today)
                 .order('reservations.date, parking_spots.number asc')
    )
  end

  def new
    @user = User.find(params[:user_id])
    @vehicle = @user.vehicles.find(params[:vehicle_id])
    @parking_spots = ParkingSpot.status_for_user_next_days(@user,
                                                           ParkitService::RESERVATION_MAX_WEEKS_INTO_THE_FUTURE * 7)
    @reservation = @vehicle.reservations.new

    authorize @reservation
  end

  def cancel
    @user = User.find(params[:user_id])
    @reservation = @user.reservations.find(params[:reservation_id])
    authorize @reservation

    if @reservation.start_time <= Time.now
      respond_to do |format|
        flash[:success] = 'Only future reservations can be cancelled.'
        format.html { redirect_to dashboard_path }
      end
    end

    @reservation.assign_attributes({
                                     cancelled: true,
                                     cancelled_at: Time.now,
                                     cancelled_by: current_user
                                   })
    if @reservation.save(validate: false)
      respond_to do |format|
        flash[:success] = 'Reservation was successfully cancelled.'
        format.html { redirect_to dashboard_path }
      end
    else
      respond_to do |format|
        flash[:danger] = 'There was a problem cancelling the reservation.'
        format.html { redirect_to dashboard_path }
      end
    end
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
