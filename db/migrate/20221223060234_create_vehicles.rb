class CreateVehicles < ActiveRecord::Migration[7.0]
  def change
    create_table :vehicles, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.boolean :ev, null: false, default: false
      t.string :license_plate_number, null: false
      t.string :make, null: false
      t.string :model, null: false
      t.integer :vehicle_type, null: false

      t.timestamps
    end

    add_index :vehicles, :license_plate_number, unique: true
  end
end
