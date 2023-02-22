class CreateReservations < ActiveRecord::Migration[7.0]
  def change
    create_table :reservations, id: :uuid do |t|
      t.references :parking_spot, null: false, foreign_key: true, type: :uuid
      t.references :vehicle, null: false, foreign_key: true, type: :uuid
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.boolean :cancelled, null: false, default: false
      t.date :date, null: false
      t.datetime :start_time, null: false
      t.datetime :end_time, null: false
      t.boolean :half_day, null: false, default: false
      t.boolean :am, null: false, default: false
      t.datetime :cancelled_at
      t.string :cancelled_by

      t.timestamps
    end
  end
end
