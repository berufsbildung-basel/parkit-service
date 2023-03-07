# frozen_string_literal: true

# Vehicle controller
class ReservationsController < AuthorizableController
  def create
    if params[:reservations].nil?
      @reservation = Reservation.new
      authorize @reservation
      respond_to do |format|
        flash[:danger] =
          'Could not reserve. You did not select a parking spot.'
        format.html { redirect_to new_user_vehicle_reservation_path(params[:user_id], params[:vehicle_id]) }
      end
      return
    end

    reservations = []

    params[:reservations].each do |reservation|
      @reservation = Reservation.new(reservation_params(reservation))
      @reservation.current_user = current_user
      authorize @reservation
      unless @reservation.save
        respond_to do |format|
          flash[:danger] =
            "There was a problem creating the reservations: #{@reservation.errors.full_messages.join(';')}"
          format.html { redirect_to dashboard_path }
        end
        return
      end

      reservations << @reservation
    end

    respond_to do |format|
      flash[:success] = 'Reservations were successfully created.'
      format.html { redirect_to dashboard_path }
    end

    message = ":car: <#{user_url(current_user.id)}|#{current_user.full_name}> created the following reservations:"
    reservations.each do |r|
      message += "\n - #{r.date}, #{r.slot_name} on spot <#{parking_spot_url(r.parking_spot.id)}|#{r.parking_spot.number}> with vehicle <#{vehicle_url(r.vehicle.id)}|#{r.vehicle.license_plate_number}> for <#{user_url(r.user.id)}|#{r.user.full_name}>"
    end
    SlackHelper.send_message(message)
  end

  def index
    @reservations = policy_scope(Reservation.active_in_the_future)
    @parking_spots = policy_scope(ParkingSpot.all.order(:number))
  end

  def new
    @user = User.find(params[:user_id])
    @vehicle = @user.vehicles.find(params[:vehicle_id])
    @parking_spots = ParkingSpot.status_for_user_next_days(@user,
                                                           ParkitService::RESERVATION_MAX_WEEKS_INTO_THE_FUTURE * 7)
    @reservation = @user.reservations.new
    @reservation.vehicle = @vehicle

    authorize @reservation
  end

  def cancel
    @user = User.find(params[:user_id])
    @reservation = @user.reservations.find(params[:reservation_id])
    authorize @reservation

    unless @reservation.can_be_cancelled?(current_user)
      respond_to do |format|
        flash[:danger] = 'Only future reservations can be cancelled.'
        format.html { redirect_to dashboard_path }
      end
      return
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

      message = ":trash-can: <#{user_url(current_user.id)}|#{current_user.full_name}> cancelled reservation:
        \n - #{@reservation.date}, #{@reservation.slot_name} on spot <#{parking_spot_url(@reservation.parking_spot.id)}|#{@reservation.parking_spot.number}> with vehicle <#{vehicle_url(@reservation.vehicle.id)}|#{@reservation.vehicle.license_plate_number}> for <#{user_url(@reservation.user.id)}|#{@reservation.user.full_name}>"
      SlackHelper.send_message(message)
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
