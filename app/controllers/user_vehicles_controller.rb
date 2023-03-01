# frozen_string_literal: true

# Vehicle controller
class UserVehiclesController < AuthorizableController
  def create
    @user = User.find(params[:user_id])
    @vehicle = @user.vehicles.create(vehicle_params)
    authorize @vehicle

    if @vehicle.save
      respond_to do |format|
        flash[:success] = 'Vehicle was successfully created.'
        format.html { redirect_to user_vehicle_path(@user.id, @vehicle.id) }
      end
    else
      respond_to do |format|
        flash[:danger] = 'There was a problem creating the vehicle.'
        format.html { render :new }
      end
    end
  end

  def destroy
    @user = User.find(params[:user_id])
    @vehicle = @user.vehicles.find(params[:id])
    authorize @vehicle

    if @vehicle.destroy
      respond_to do |format|
        flash[:success] = 'Vehicle was successfully deleted.'
        format.html { redirect_to user_vehicles_path(@user.id) }
      end
    else
      respond_to do |format|
        flash[:danger] = 'There was a problem deleting the vehicle.'
        format.html { render :show }
      end
    end
  end

  def edit
    @user = User.find(params[:user_id])
    @vehicle = @user.vehicles.find(params[:id])
    authorize @vehicle
  end

  def index
    @user = User.find(params[:user_id])
    @vehicles = policy_scope(@user.vehicles)
  end

  def new
    @user = User.find(params[:user_id])
    @vehicle = @user.vehicles.new
    authorize @vehicle
  end

  def show
    @user = User.find(params[:user_id])
    @vehicle = @user.vehicles.find(params[:id])
    authorize @vehicle
  end

  def update
    @user = User.find(params[:user_id])
    @vehicle = @user.vehicles.find(params[:id])
    authorize @vehicle

    if @vehicle.update(vehicle_params)
      respond_to do |format|
        flash[:success] = 'Vehicle was successfully updated.'
        format.html { redirect_to user_vehicle_path(@user.id, @vehicle.id) }
      end
    else
      respond_to do |format|
        flash[:danger] = 'There was a problem updating the vehicle.'
        format.html { render :edit }
      end
    end
  end

  private

  def vehicle_params
    params.require(:vehicle).permit(
      :ev,
      :license_plate_number,
      :make,
      :model
    )
  end
end
