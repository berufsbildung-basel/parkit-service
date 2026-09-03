# frozen_string_literal: true

class AddGuestReservationSupportToReservations < ActiveRecord::Migration[7.1]
  def change
    add_column :reservations, :type, :string
    add_index :reservations, :type

    change_column_null :reservations, :user_id, true
    change_column_null :reservations, :vehicle_id, true

    add_column :reservations, :guest_name, :string
    add_column :reservations, :guest_license_plate, :string

    add_reference :reservations, :created_by, type: :uuid, foreign_key: { to_table: :users }, index: true
  end
end
