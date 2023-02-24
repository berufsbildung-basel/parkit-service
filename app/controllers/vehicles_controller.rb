# frozen_string_literal: true

# Vehicle controller
class VehiclesController < ApplicationController
  def create
    @vehicle = Vehicle.create(vehicle_params)
    authorize @vehicle

    if @vehicle.save
      respond_to do |format|
        flash[:success] = 'Vehicle was successfully created.'
        format.html { redirect_to vehicle_path(@vehicle.id) }
      end
    else
      respond_to do |format|
        flash[:danger] = 'There was a problem creating the vehicle.'
        format.html { render :new }
      end
    end
  end

  def destroy
    @vehicle = Vehicle.find(params[:id])
    authorize @vehicle

    if @vehicle.destroy
      respond_to do |format|
        flash[:success] = 'Vehicle was successfully deleted.'
        format.html { redirect_to vehicle_path(@user.id) }
      end
    else
      respond_to do |format|
        flash[:danger] = 'There was a problem deleting the vehicle.'
        format.html { render :show }
      end
    end
  end

  def edit
    @vehicle = Vehicle.find(params[:id])
    authorize @vehicle
  end

  def index
    @vehicles = policy_scope(Vehicle.all.order(:license_plate_number))
  end

  def new
    @vehicle = Vehicle.new
    @users = User.all
    authorize @vehicle
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

  private

  def vehicle_params
    params.require(:vehicle).permit(
      :ev,
      :license_plate_number,
      :make,
      :model,
      :user_id
    )
  end
end
