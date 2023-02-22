class CreateParkingSpots < ActiveRecord::Migration[7.0]
  def change
    create_table :parking_spots, id: :uuid do |t|
      t.integer :number, null: false
      t.boolean :charger_available, null: false, default: false
      t.boolean :unavailable, null: false, default: false
      t.string :unavailability_reason

      t.timestamps
    end

    add_index :parking_spots, :number, unique: true
  end
end
