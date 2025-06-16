class AddAllowedVehicleTypeToParkingSpots < ActiveRecord::Migration[7.0]
  def change
    add_column :parking_spots, :allowed_vehicle_type, :integer, null: false, default: 0
  end
end
