class AddArchivedToParkingSpots < ActiveRecord::Migration[7.1]
  def change
    add_column :parking_spots, :archived, :boolean, default: false, null: false
  end
end
