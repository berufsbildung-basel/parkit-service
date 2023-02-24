# frozen_string_literal: true

# ParkingSpot controller
class ParkingSpotsController < ApplicationController
  def create
    @parking_spot = ParkingSpot.create(parking_spot_params)
    authorize @parking_spot

    if @parking_spot.save
      respond_to do |format|
        flash[:success] = 'Parking spot was successfully created.'
        format.html { redirect_to parking_spot_path(@parking_spot.id) }
      end
    else
      respond_to do |format|
        flash[:danger] = 'There was a problem creating the parking spot.'
        format.html { render :new }
      end
    end
  end

  def destroy
    @parking_spot = ParkingSpot.find(params[:id])
    authorize @parking_spot

    if @parking_spot.destroy
      respond_to do |format|
        flash[:success] = 'Parking spot was successfully deleted.'
        format.html { redirect_to parking_spots_path }
      end
    else
      respond_to do |format|
        flash[:danger] = 'There was a problem deleting the parking spot.'
        format.html { render :show }
      end
    end
  end

  def edit
    @parking_spot = ParkingSpot.find(params[:id])
    authorize @parking_spot
  end

  def index
    @parking_spots = policy_scope(ParkingSpot.all.order(:number))
  end

  def new
    @parking_spot = ParkingSpot.new
    authorize @parking_spot
  end

  def show
    @parking_spot = ParkingSpot.find(params[:id])
    authorize @parking_spot
  end

  def update
    @parking_spot = ParkingSpot.find(params[:id])
    authorize @parking_spot

    if @parking_spot.update(parking_spot_params)
      respond_to do |format|
        flash[:success] = 'Parking spot was successfully updated.'
        format.html { redirect_to parking_spot_path(@parking_spot.id) }
      end
    else
      respond_to do |format|
        flash[:danger] = 'There was a problem updating the parking spot.'
        format.html { render :edit }
      end
    end
  end

  private

  def parking_spot_params
    params.require(:parking_spot).permit(
      :number,
      :charger_available,
      :unavailable,
      :unavailability_reason
    )
  end
end
