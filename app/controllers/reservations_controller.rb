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

    response_sent = false

    params[:reservations].each do |reservation|
      @reservation = Reservation.new(reservation_params(reservation))
      @reservation.current_user = current_user
      authorize @reservation

      parking_spot = ParkingSpot.find_by(id: @reservation.parking_spot_id)

      if parking_spot.nil?
        flash[:danger] = 'The selected parking spot does not exist anymore.'
        redirect_to new_user_vehicle_reservation_path(params[:user_id], params[:vehicle_id])
        response_sent = true
        break
      end

      if parking_spot.archived?
        flash[:danger] = 'The selected parking spot is no longer available for reservation.'
        redirect_to new_user_vehicle_reservation_path(params[:user_id], params[:vehicle_id])
        response_sent = true
        break
      end

      unless @reservation.save
        flash[:danger] = "There was a problem creating the reservations: #{@reservation.errors.full_messages.join(';')}"
        redirect_to dashboard_path
        response_sent = true
        break
      end

      reservations << @reservation
    end

    unless response_sent
      respond_to do |format|
        flash[:success] = 'Reservations were successfully created.'
        format.html { redirect_to dashboard_path }
      end
    end

    message = ":car: <#{user_url(current_user.id)}|#{current_user.full_name}> created the following reservations:"
    reservations.each do |r|
      message += "\n - #{r.date}, #{r.slot_name} on spot <#{parking_spot_url(r.parking_spot.id)}|#{r.parking_spot.number}> with vehicle <#{vehicle_url(r.vehicle.id)}|#{r.vehicle.license_plate_number}> for <#{user_url(r.user.id)}|#{r.user.full_name}>"
    end
    SlackHelper.send_message(message)
  end

  def index
    @reservations = policy_scope(Reservation.all)
    @parking_spots = policy_scope(ParkingSpot.all.order(:number))
    @past_reservations = @reservations.active_in_the_past.page(params[:past_page]).per(25)
    @cancelled_reservations = @reservations.cancelled.page(params[:cancelled_page]).per(25)

    # Chart data for past 3 months by vehicle type
    three_months_ago = Date.today - 3.months
    base_scope = @reservations.active_between(three_months_ago, Date.today).joins(:vehicle)

    @chart_data = [
      { name: 'Total', data: base_scope.unscope(:order).group_by_day(:start_time).count },
      { name: 'Car', data: base_scope.where(vehicles: { vehicle_type: 0 }).unscope(:order).group_by_day(:start_time).count },
      { name: 'Motorcycle', data: base_scope.where(vehicles: { vehicle_type: 1 }).unscope(:order).group_by_day(:start_time).count }
    ]

    # Monthly revenue chart (past 24 months) - stacked bar
    twenty_four_months_ago = Date.today - 24.months
    monthly_base = @reservations.active_between(twenty_four_months_ago, Date.today).joins(:vehicle)

    @monthly_revenue_chart = [
      { name: 'Car', data: monthly_base.where(vehicles: { vehicle_type: 0 }).unscope(:order).group_by_month(:start_time).sum(:price) },
      { name: 'Motorcycle', data: monthly_base.where(vehicles: { vehicle_type: 1 }).unscope(:order).group_by_month(:start_time).sum(:price) }
    ]

    # Yearly statistics table
    current_year = Date.today.year
    last_year = current_year - 1

    @yearly_stats = {
      current_year => calculate_yearly_stats(current_year),
      last_year => calculate_yearly_stats(last_year)
    }

    # Occupancy heatmap (past 24 months)
    @occupancy_heatmap = calculate_occupancy_heatmap
  end

  def new
    @user = User.find(params[:user_id])
    @vehicle = @user.vehicles.find(params[:vehicle_id])
    all_spots = ParkingSpot.status_for_user_next_days(@user, ParkitService::RESERVATION_MAX_WEEKS_INTO_THE_FUTURE * 7)
    # Filter parking spots for each day by allowed_vehicle_type
    @parking_spots = {}
    all_spots.each do |week, days|
      @parking_spots[week] = {}
      days.each do |date, spots|
        @parking_spots[week][date] = spots.select { |spot| spot.allowed_vehicle_type == @vehicle.vehicle_type }
      end
    end
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

  def calculate_yearly_stats(year)
    start_date = Date.new(year, 1, 1)
    end_date = [Date.new(year, 12, 31), Date.today].min

    # Count active (non-archived) spots by type
    car_spots = ParkingSpot.where(allowed_vehicle_type: 0, archived: false).count
    motorcycle_spots = ParkingSpot.where(allowed_vehicle_type: 1, archived: false).count

    base = Reservation.active_between(start_date, end_date).joins(:vehicle)
    car_reservations = base.where(vehicles: { vehicle_type: 0 })
    motorcycle_reservations = base.where(vehicles: { vehicle_type: 1 })

    car_count = car_reservations.count
    motorcycle_count = motorcycle_reservations.count
    car_revenue = car_reservations.sum(:price)
    motorcycle_revenue = motorcycle_reservations.sum(:price)

    {
      car_spots: car_spots,
      car_count: car_count,
      car_revenue: car_revenue,
      car_revenue_per_spot: car_spots.positive? ? (car_revenue / car_spots).round(2) : 0,
      motorcycle_spots: motorcycle_spots,
      motorcycle_count: motorcycle_count,
      motorcycle_revenue: motorcycle_revenue,
      # 4 motorcycle spots = 1 car-equivalent space
      motorcycle_revenue_per_car_equivalent: motorcycle_revenue.round(2),
      total_count: base.count,
      total_revenue: base.sum(:price)
    }
  end

  def calculate_occupancy_heatmap
    # Generate list of months (past 24 months)
    months = []
    24.times do |i|
      months << (Date.today - i.months).beginning_of_month
    end
    months.reverse!

    # Get all active parking spots
    spots = ParkingSpot.where(archived: false).order(:allowed_vehicle_type, :number)

    # Pre-fetch all reservations for the date range
    start_date = months.first
    end_date = Date.today
    reservations_by_spot_month = Reservation.active_between(start_date, end_date)
                                            .group(:parking_spot_id)
                                            .group_by_month(:date, format: '%Y-%m')
                                            .count

    spot_data = spots.map do |spot|
      monthly_occupancy = months.map do |month|
        month_key = month.strftime('%Y-%m')
        reservation_count = reservations_by_spot_month[[spot.id, month_key]] || 0

        # Calculate working days in the month (exclude weekends)
        month_end = [month.end_of_month, Date.today].min
        working_days = (month..month_end).count { |d| !d.saturday? && !d.sunday? }

        # Calculate occupancy percentage
        working_days.positive? ? ((reservation_count.to_f / working_days) * 100).round(1) : 0
      end

      {
        number: spot.number,
        type: spot.allowed_vehicle_type,
        data: monthly_occupancy
      }
    end

    {
      months: months.map { |m| m.strftime('%b %y') },
      spots: spot_data
    }
  end

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
