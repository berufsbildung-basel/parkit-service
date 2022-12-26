# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2022_12_23_061122) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "parking_spots", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "number", null: false
    t.boolean "charger_available", default: false, null: false
    t.boolean "unavailable", default: false, null: false
    t.string "unavailability_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["number"], name: "index_parking_spots_on_number", unique: true
  end

  create_table "reservations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "parking_spot_id", null: false
    t.uuid "vehicle_id", null: false
    t.uuid "user_id", null: false
    t.boolean "cancelled", default: false, null: false
    t.date "date", null: false
    t.datetime "start_time", null: false
    t.datetime "end_time", null: false
    t.boolean "half_day", default: false, null: false
    t.boolean "am", default: false, null: false
    t.datetime "cancelled_at"
    t.string "cancelled_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parking_spot_id"], name: "index_reservations_on_parking_spot_id"
    t.index ["user_id"], name: "index_reservations_on_user_id"
    t.index ["vehicle_id"], name: "index_reservations_on_vehicle_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", null: false
    t.string "oktaId", null: false
    t.string "username", null: false
    t.integer "role"
    t.string "encrypted_password"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.boolean "disabled", default: false, null: false
    t.string "first_name"
    t.string "last_name"
    t.string "preferred_language", default: "en", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["oktaId"], name: "index_users_on_oktaId", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "vehicles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.boolean "ev", default: false, null: false
    t.string "license_plate_number", null: false
    t.string "make", null: false
    t.string "model", null: false
    t.integer "vehicle_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["license_plate_number"], name: "index_vehicles_on_license_plate_number", unique: true
    t.index ["user_id"], name: "index_vehicles_on_user_id"
  end

  add_foreign_key "reservations", "parking_spots"
  add_foreign_key "reservations", "users"
  add_foreign_key "reservations", "vehicles"
  add_foreign_key "vehicles", "users"
end
