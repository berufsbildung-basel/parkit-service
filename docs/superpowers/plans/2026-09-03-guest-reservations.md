# Guest Reservations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let facilities staff (and admins) book non-billable parking reservations for guests who aren't registered users, including multiple guest bookings on the same day, without weakening any existing validation for registered users.

**Architecture:** A `GuestReservation < Reservation` single-table-inheritance subclass carries a nullable `user`/`vehicle` and its own `guest_name`/`guest_license_plate` columns. `Reservation` grows a small set of polymorphic predicate methods (`requires_registered_owner?`, `owner_name`) that `GuestReservation` overrides; the validator, policy, controller, and views call those predicates instead of branching on class or nil-checking `user`/`vehicle` directly. A new `facilities` role plus a `User#can_manage_reservations?` predicate (== `admin? || facilities?`) gates the new capability everywhere the old `admin?`-only checks used to gate "book/cancel for someone else."

**Tech Stack:** Rails 7.1 (Ruby, rbenv-managed), Postgres, RSpec + Devise test helpers (no FactoryBot in this repo - fixtures are built inline with `Model.create!`), Pundit for authorization, plain ERB + vanilla JS (importmap, no bundler/Jest) for the booking grid.

**Spec:** `docs/superpowers/specs/2026-09-03-guest-reservations-design.md` - read it alongside this plan; it has the full rationale (why STI over a placeholder user or a separate table, why `IS DISTINCT FROM` and not `where.not`, why facilities gets billing-visible views).

## Environment note (applies to every task)

Local Ruby resolves to system Ruby 2.6 unless rbenv shims are on `PATH`, and specs need a running local Postgres. Every `bin/rails` / `bundle exec rspec` command below assumes:

```bash
export PATH="$HOME/.rbenv/shims:$PATH"
pg_isready || brew services start postgresql   # or however Postgres is normally started locally
```

## Global Constraints

- Guests are car-only. No `guest_vehicle_type` field - enforced by a hardcoded check against `parking_spot.allowed_vehicle_type == 'car'`, not a stored value.
- The one-reservation-per-day cap (`RESERVATION_MAX_RESERVATIONS_PER_DAY`, `config/application.rb`) stays enforced, unchanged, for every reservation with a registered owner - including one a facilities/admin user books on behalf of another registered member. Only reservations with no registered owner (`GuestReservation`) skip this check.
- `admin?`-only checks that should now also admit facilities staff use the new `User#can_manage_reservations?` predicate, not a repeated `admin? || facilities?` inline.
- No new columns beyond what's in the spec's Data Model table: `type`, `guest_name`, `guest_license_plate`, `created_by_id`, plus making `user_id`/`vehicle_id` nullable.
- Existing nested routes/behavior (`/users/:user_id/reservations/...`) must keep working unchanged for registered users - every task that touches shared code (`ReservationsController`, `ReservationPolicy`, `ReservationValidator`, `Reservation`) needs a regression test proving the non-guest path is unaffected.

---

### Task 1: `facilities` role + `User#can_manage_reservations?`

**Files:**
- Modify: `app/models/user.rb:14` (role enum), add new public method
- Test: `spec/models/user_spec.rb`

**Interfaces:**
- Produces: `User#can_manage_reservations?` (no args, returns `true`/`false`) - every later task that currently would write `user.admin? || user.facilities?` calls this instead.

- [ ] **Step 1: Write the failing tests**

Add to `spec/models/user_spec.rb`, inside `context 'creation'` (after the existing `it 'successfully assigns valid roles'` block, so it shares the file's style):

```ruby
    it 'successfully assigns the facilities role' do
      user = User.create!({
                            username: Faker::Internet.username,
                            email: Faker::Internet.email,
                            first_name: Faker::Name.first_name,
                            last_name: Faker::Name.last_name
                          })

      user.role = 'facilities'
      expect(user.facilities?).to eql(true)
      expect(user.admin?).to eql(false)
    end

    it 'reports can_manage_reservations? correctly per role' do
      admin = User.create!(username: Faker::Internet.username, email: Faker::Internet.email,
                            first_name: Faker::Name.first_name, last_name: Faker::Name.last_name, role: :admin)
      facilities = User.create!(username: Faker::Internet.username, email: Faker::Internet.email,
                                 first_name: Faker::Name.first_name, last_name: Faker::Name.last_name, role: :facilities)
      regular = User.create!(username: Faker::Internet.username, email: Faker::Internet.email,
                              first_name: Faker::Name.first_name, last_name: Faker::Name.last_name)

      expect(admin.can_manage_reservations?).to eql(true)
      expect(facilities.can_manage_reservations?).to eql(true)
      expect(regular.can_manage_reservations?).to eql(false)
    end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bundle exec rspec spec/models/user_spec.rb -e "facilities role" -e "can_manage_reservations"`
Expected: FAIL - `facilities` is not a valid role (`ArgumentError`/inclusion validation error) and `can_manage_reservations?` is undefined.

- [ ] **Step 3: Implement**

In `app/models/user.rb`, change line 14:

```ruby
  enum role: %i[user led_matrix admin facilities]
```

Add a new public method (anywhere in the public section, e.g. right after `set_default_role`):

```ruby
  def can_manage_reservations?
    admin? || facilities?
  end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bundle exec rspec spec/models/user_spec.rb`
Expected: PASS (full file, not just the new examples - confirms no regression on the existing role tests)

- [ ] **Step 5: Commit**

```bash
git add app/models/user.rb spec/models/user_spec.rb
git commit -m "feat: add facilities role and can_manage_reservations? predicate"
```

---

### Task 2: Migration - guest reservation columns

**Files:**
- Create: `db/migrate/<timestamp>_add_guest_reservation_support_to_reservations.rb` (timestamp assigned by the generator in Step 1)
- Modify: `db/schema.rb` (auto-updated by `db:migrate`, do not hand-edit)
- Test: `spec/models/reservation_spec.rb` (temporary probe, see Step 2/5)

**Interfaces:**
- Produces: `reservations.type` (string, nullable), `reservations.user_id`/`reservations.vehicle_id` (now nullable), `reservations.guest_name` (string, nullable), `reservations.guest_license_plate` (string, nullable), `reservations.created_by_id` (uuid FK -> users, nullable).

- [ ] **Step 1: Generate the migration file**

Run: `bin/rails generate migration AddGuestReservationSupportToReservations`

This creates `db/migrate/<timestamp>_add_guest_reservation_support_to_reservations.rb` with an empty `change` method. Note the generated filename for the remaining steps.

- [ ] **Step 2: Write a failing probe spec**

Add a temporary `it` block at the end of the `context 'creation'` block in `spec/models/reservation_spec.rb` (this step's spec is superseded by Task 3's real `GuestReservation` specs - it exists only to prove the migration itself works before any model code changes):

```ruby
    it 'allows a nil user/vehicle and a guest_name/guest_license_plate on the schema' do
      reservation = Reservation.new(
        parking_spot:,
        date: Date.today,
        guest_name: 'Probe Guest',
        guest_license_plate: 'ZH 0000'
      )

      expect(reservation.guest_name).to eql('Probe Guest')
      expect(reservation.guest_license_plate).to eql('ZH 0000')
      expect(reservation.user).to be_nil
      expect(reservation.vehicle).to be_nil
    end
```

- [ ] **Step 3: Run it to verify it fails**

Run: `bundle exec rspec spec/models/reservation_spec.rb -e "allows a nil user/vehicle"`
Expected: FAIL with `ActiveModel::UnknownAttributeError: unknown attribute 'guest_name' for Reservation.` (the column doesn't exist yet)

- [ ] **Step 4: Write the migration**

Replace the generated file's `change` method body:

```ruby
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
```

Run: `bin/rails db:migrate`

- [ ] **Step 5: Run the probe spec to verify it passes, then delete it**

Run: `bundle exec rspec spec/models/reservation_spec.rb -e "allows a nil user/vehicle"`
Expected: PASS

Delete the probe `it` block added in Step 2 - it was only there to verify the migration; Task 3 adds the real, permanent coverage for `GuestReservation`'s nullable associations.

- [ ] **Step 6: Confirm the base Reservation regression suite still passes**

Run: `bundle exec rspec spec/models/reservation_spec.rb spec/validators/reservation_validator_spec.rb`
Expected: PASS (nullable columns don't change behavior for rows that still set `user`/`vehicle`)

- [ ] **Step 7: Commit**

```bash
git add db/migrate/*_add_guest_reservation_support_to_reservations.rb db/schema.rb
git commit -m "feat: add guest reservation columns to reservations table"
```

---

### Task 3: `GuestReservation` STI model + `Reservation` polymorphic methods

**Files:**
- Modify: `app/models/reservation.rb` (associations, new public methods, `can_be_cancelled?`, `set_price` refactor)
- Create: `app/models/guest_reservation.rb`
- Test: `spec/models/reservation_spec.rb`, Create: `spec/models/guest_reservation_spec.rb`

**Interfaces:**
- Consumes: `User#can_manage_reservations?` (Task 1)
- Produces: `Reservation#requires_registered_owner?` (returns `true`, overridden to `false` on `GuestReservation`), `Reservation#owner_name` (returns `user&.full_name`, overridden to `guest_name` on `GuestReservation`), `GuestReservation.policy_class` (class method, returns `ReservationPolicy`) - Task 6/7/8/9 all call `authorize` on `GuestReservation` instances and depend on this resolving correctly instead of raising `NameError: uninitialized constant GuestReservationPolicy`.

- [ ] **Step 1: Write the failing tests**

Create `spec/models/guest_reservation_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GuestReservation, type: :model do
  let!(:car_spot) { ParkingSpot.create!(number: 30, allowed_vehicle_type: :car) }
  let!(:motorcycle_spot) { ParkingSpot.create!(number: 31, allowed_vehicle_type: :motorcycle) }

  context 'validation' do
    it 'requires a guest name' do
      reservation = GuestReservation.new(parking_spot: car_spot, date: Date.today, guest_license_plate: 'ZH 1234')

      expect(reservation.valid?).to eql(false)
      expect(reservation.errors.map(&:attribute)).to include(:guest_name)
    end

    it 'requires a guest license plate' do
      reservation = GuestReservation.new(parking_spot: car_spot, date: Date.today, guest_name: 'Jane Guest')

      expect(reservation.valid?).to eql(false)
      expect(reservation.errors.map(&:attribute)).to include(:guest_license_plate)
    end

    it 'rejects a motorcycle-only parking spot' do
      reservation = GuestReservation.new(parking_spot: motorcycle_spot, date: Date.today,
                                          guest_name: 'Jane Guest', guest_license_plate: 'ZH 1234')

      expect(reservation.valid?).to eql(false)
      expect(reservation.errors.first.attribute).to eql(:parking_spot)
    end

    it 'is valid with a name, plate, and a car parking spot, with no user or vehicle' do
      reservation = GuestReservation.new(parking_spot: car_spot, date: Date.today,
                                          guest_name: 'Jane Guest', guest_license_plate: 'ZH 1234')

      expect(reservation.valid?).to eql(true)
      expect(reservation.user).to be_nil
      expect(reservation.vehicle).to be_nil
    end
  end

  context 'pricing' do
    it 'is always free, on a weekday' do
      weekday = Date.today
      weekday += 1 until weekday.on_weekday?

      reservation = GuestReservation.create!(parking_spot: car_spot, date: weekday,
                                              guest_name: 'Jane Guest', guest_license_plate: 'ZH 1234')

      expect(reservation.price).to eq(0.0)
    end
  end

  context 'polymorphic methods' do
    it 'requires_registered_owner? is false' do
      expect(GuestReservation.new.requires_registered_owner?).to eql(false)
    end

    it 'owner_name returns the guest name' do
      expect(GuestReservation.new(guest_name: 'Jane Guest').owner_name).to eql('Jane Guest')
    end

    it 'resolves its Pundit policy_class to ReservationPolicy' do
      expect(GuestReservation.policy_class).to eq(ReservationPolicy)
    end
  end

  context 'billing visibility' do
    it 'is invisible to per-user billing, since it has no user to join through' do
      guest = GuestReservation.create!(parking_spot: car_spot, date: Date.today,
                                        guest_name: 'Jane Guest', guest_license_plate: 'ZH 1234')

      expect(User.joins(:reservations).where(reservations: { id: guest.id })).to be_empty
    end
  end
end
```

Add to `spec/models/reservation_spec.rb`, inside `context 'creation'`:

```ruby
    it 'requires_registered_owner? is true for a base reservation' do
      expect(Reservation.new.requires_registered_owner?).to eql(true)
    end

    it 'owner_name returns the user\'s full name for a base reservation' do
      reservation = Reservation.new(user: user1)
      expect(reservation.owner_name).to eql(user1.full_name)
    end

    it 'can_be_cancelled? allows facilities staff to cancel a started reservation' do
      facilities_user = User.create!(username: Faker::Internet.username, email: Faker::Internet.email,
                                      first_name: Faker::Name.first_name, last_name: Faker::Name.last_name,
                                      role: :facilities)
      reservation = Reservation.create!(parking_spot:, vehicle: car1, user: user1, date: Date.today)

      expect(reservation.can_be_cancelled?(facilities_user)).to eql(true)
    end
```

(This reuses `parking_spot`/`user1`/`car1` already set up in that file's `before(:each)`.)

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bundle exec rspec spec/models/guest_reservation_spec.rb spec/models/reservation_spec.rb`
Expected: FAIL - `uninitialized constant GuestReservation`, `undefined method 'requires_registered_owner?'`, `undefined method 'owner_name'`.

- [ ] **Step 3: Implement**

In `app/models/reservation.rb`, change lines 5-7:

```ruby
  belongs_to :parking_spot
  belongs_to :vehicle, optional: true
  belongs_to :user, optional: true
  belongs_to :created_by, class_name: 'User', optional: true
```

Add these two public methods (e.g. right after `can_be_cancelled?`):

```ruby
  def requires_registered_owner?
    true
  end

  def owner_name
    user&.full_name
  end
```

Change `can_be_cancelled?` (currently `current_user.admin? || start_time > Time.now`):

```ruby
  def can_be_cancelled?(current_user)
    current_user.can_manage_reservations? || start_time > Time.now
  end
```

Create `app/models/guest_reservation.rb`:

```ruby
# frozen_string_literal: true

# A reservation booked by facilities/admin staff on behalf of someone who
# isn't a registered user. Has no associated User or Vehicle record.
class GuestReservation < Reservation
  def self.policy_class
    ReservationPolicy
  end

  validates :guest_name, presence: true
  validates :guest_license_plate, presence: true
  validate :parking_spot_is_car_type

  def requires_registered_owner?
    false
  end

  def owner_name
    guest_name
  end

  private

  def set_price
    self.price = 0.0
  end

  def parking_spot_is_car_type
    return if parking_spot.nil?

    errors.add(:parking_spot, :guests_car_only) unless parking_spot.allowed_vehicle_type == 'car'
  end
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bundle exec rspec spec/models/guest_reservation_spec.rb spec/models/reservation_spec.rb`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/models/reservation.rb app/models/guest_reservation.rb spec/models/guest_reservation_spec.rb spec/models/reservation_spec.rb
git commit -m "feat: add GuestReservation STI subclass with polymorphic owner methods"
```

---

### Task 4: `ReservationValidator` - skip registered-owner checks for guest reservations

**Files:**
- Modify: `app/validators/reservation_validator.rb`
- Test: `spec/validators/reservation_validator_spec.rb`

**Interfaces:**
- Consumes: `Reservation#requires_registered_owner?` (Task 3)

- [ ] **Step 1: Write the failing tests**

Add to `spec/validators/reservation_validator_spec.rb`, inside `context 'validation'` (reuses `parking_spot`, `unavailable_parking_spot`, `user1`, `car1` from that context's `before(:each)`):

```ruby
    it 'does not require a registered user or vehicle for a guest reservation' do
      reservation = GuestReservation.new(parking_spot:, date: Date.today,
                                          guest_name: 'Guest', guest_license_plate: 'ZH 1234')

      expect(reservation.valid?).to eql(true)
    end

    it 'still rejects a guest reservation on a parking spot marked unavailable' do
      reservation = GuestReservation.new(parking_spot: unavailable_parking_spot, date: Date.today,
                                          guest_name: 'Guest', guest_license_plate: 'ZH 1234')

      expect(reservation.valid?).to eql(false)
      expect(reservation.errors.first.full_message).to eql('Parking spot has been marked unavailable')
    end

    it 'allows facilities to create a second guest reservation on the same day (bypasses the per-day cap)' do
      GuestReservation.create!(parking_spot:, date: Date.today, guest_name: 'Guest One', guest_license_plate: 'G1')
      second_spot = ParkingSpot.create!(number: 20)

      reservation = GuestReservation.new(parking_spot: second_spot, date: Date.today,
                                          guest_name: 'Guest Two', guest_license_plate: 'G2')

      expect(reservation.valid?).to eql(true)
    end

    it 'still caps a registered user at one reservation per day when a guest reservation exists the same day' do
      Reservation.create!(parking_spot:, vehicle: car1, user: user1, date: Date.today)
      second_spot = ParkingSpot.create!(number: 21)
      GuestReservation.create!(parking_spot: second_spot, date: Date.today, guest_name: 'Guest', guest_license_plate: 'G1')

      third_spot = ParkingSpot.create!(number: 22)
      reservation = Reservation.new(parking_spot: third_spot, vehicle: car1, user: user1, date: Date.today)

      expect(reservation.valid?).to eql(false)
      expect(reservation.errors.first.full_message).to eql('User already has a reservation on that day')
    end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bundle exec rspec spec/validators/reservation_validator_spec.rb`
Expected: FAIL - a `GuestReservation` currently fails validation because `validate_user_is_not_disabled` etc. call `reservation.user.disabled?` on a `nil` user (`NoMethodError`).

- [ ] **Step 3: Implement**

In `app/validators/reservation_validator.rb`, change `perform_validation` and the three user/vehicle-dependent checks:

```ruby
  def perform_validation(reservation)
    reservation.present? &&
      (reservation.user.present? || !reservation.requires_registered_owner?) &&
      (reservation.vehicle.present? || !reservation.requires_registered_owner?) &&
      reservation.parking_spot.present?
  end

  def validate_user_is_not_disabled(reservation)
    return unless reservation.requires_registered_owner?
    return unless reservation.user.disabled?

    reservation.errors.add(:user, :marked_disabled)
  end
```

```ruby
  def validate_user_does_not_exceed_reservations_per_day(reservation)
    return unless reservation.requires_registered_owner?
    return unless reservation.date.present?

    return unless reservation.user.exceeds_reservations_per_day?(reservation.date, reservation.id)

    reservation.errors.add(:user, :exceeds_max_reservations_per_day)
  end
```

```ruby
  def validate_vehicle_belongs_to_user(reservation)
    return unless reservation.requires_registered_owner?
    return unless reservation.vehicle.user.nil? || (reservation.vehicle.user.id != reservation.user.id)

    reservation.errors.add(:vehicle, :does_not_belong_to_reservation_user)
  end
```

`validate_parking_spot_is_not_unavailable` and `validate_overlap` are unchanged - they must keep running unconditionally (Task 5 covers `validate_overlap`'s own nil-user bug inside the scope it calls).

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bundle exec rspec spec/validators/reservation_validator_spec.rb`
Expected: PASS

- [ ] **Step 5: Run the full validator + model regression suite**

Run: `bundle exec rspec spec/validators/reservation_validator_spec.rb spec/models/reservation_spec.rb spec/models/guest_reservation_spec.rb`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app/validators/reservation_validator.rb spec/validators/reservation_validator_spec.rb
git commit -m "feat: skip registered-owner validations for guest reservations"
```

---

### Task 5: Fix the overlap-scope double-booking bug (Critical)

**Files:**
- Modify: `app/models/reservation.rb:73-84` (the `overlapping_on_date_and_parking_spot` scope)
- Test: `spec/validators/reservation_validator_spec.rb`

This is the bug three independent reviewers found in the design spec: `where.not(user_id: user.id)` compiles to `WHERE user_id != '<uuid>'`, and under SQL three-valued logic a `NULL` `user_id` (every guest reservation) makes that comparison unknown, not true - so a registered member's overlap check silently drops any guest reservation already occupying the same spot/time, allowing a double-booking.

- [ ] **Step 1: Write the failing tests**

Add to `spec/validators/reservation_validator_spec.rb`, inside `context 'validation'`:

```ruby
    it 'rejects a guest reservation overlapping another guest on the same spot/time' do
      GuestReservation.create!(parking_spot:, date: Date.today, guest_name: 'Guest One', guest_license_plate: 'G1')

      reservation = GuestReservation.new(parking_spot:, date: Date.today,
                                          guest_name: 'Guest Two', guest_license_plate: 'G2')

      expect(reservation.valid?).to eql(false)
      expect(reservation.errors.first.full_message)
        .to eql('Reservation overlaps with existing reservation on that day and parking spot')
    end

    it 'rejects a registered member booking over an existing guest reservation on the same spot/time' do
      GuestReservation.create!(parking_spot:, date: Date.today, guest_name: 'Guest One', guest_license_plate: 'G1')

      reservation = Reservation.new(parking_spot:, vehicle: car1, user: user1, date: Date.today)

      expect(reservation.valid?).to eql(false)
      expect(reservation.errors.first.full_message)
        .to eql('Reservation overlaps with existing reservation on that day and parking spot')
    end

    it 'rejects a guest reservation booked over an existing registered member reservation on the same spot/time' do
      Reservation.create!(parking_spot:, vehicle: car1, user: user1, date: Date.today)

      reservation = GuestReservation.new(parking_spot:, date: Date.today,
                                          guest_name: 'Guest', guest_license_plate: 'G1')

      expect(reservation.valid?).to eql(false)
      expect(reservation.errors.first.full_message)
        .to eql('Reservation overlaps with existing reservation on that day and parking spot')
    end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bundle exec rspec spec/validators/reservation_validator_spec.rb -e "overlap"`
Expected: The first test (`guest vs guest`) passes already (nil user, no exclusion filter). The second test (`registered member over existing guest`) FAILS - `reservation.valid?` returns `true` because the `where.not(user_id: user1.id)` clause silently drops the guest's `NULL` row. This is the double-booking bug - reproduce it before fixing it.

- [ ] **Step 3: Implement**

In `app/models/reservation.rb`, change the `overlapping_on_date_and_parking_spot` scope (lines 73-84):

```ruby
  scope :overlapping_on_date_and_parking_spot, lambda { |date, parking_spot, user, start_time, end_time|
    scope = active_on_date(date)
            .includes(:vehicle)
            .includes(:user)
            .where(parking_spot:)
    scope = scope.where('reservations.user_id IS DISTINCT FROM ?', user.id) if user.present?
    scope.where(
      '? <= reservations.end_time AND ? >= reservations.start_time',
      start_time,
      end_time
    )
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bundle exec rspec spec/validators/reservation_validator_spec.rb -e "overlap"`
Expected: PASS - all three new tests, including the "rejects creating a reservations that overlap" registered-vs-registered case (still `skip`ped for the unrelated motorcycle-spot TODO, unaffected by this change).

- [ ] **Step 5: Run the full validator suite to confirm no regression**

Run: `bundle exec rspec spec/validators/reservation_validator_spec.rb spec/models/reservation_spec.rb`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app/models/reservation.rb spec/validators/reservation_validator_spec.rb
git commit -m "fix: use IS DISTINCT FROM in overlap scope to catch guest-vs-member double-booking"
```

---

### Task 6: `ReservationPolicy` - `can_manage_reservations?`, `Scope`, `new_guest?`

**Files:**
- Modify: `app/policies/reservation_policy.rb`
- Create: `spec/policies/reservation_policy_spec.rb`

**Interfaces:**
- Consumes: `User#can_manage_reservations?` (Task 1), `GuestReservation.policy_class` (Task 3)
- Produces: `ReservationPolicy#new_guest?` - Task 8's `new_guest` controller action calls plain `authorize @reservation`, which Pundit infers as `:new_guest?` from the action name.

- [ ] **Step 1: Write the failing tests**

Create `spec/policies/reservation_policy_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReservationPolicy, type: :model do
  let(:admin) do
    User.create!(username: 'admin-user', email: 'admin@example.com', first_name: 'Admin', last_name: 'User',
                 role: :admin)
  end
  let(:facilities_user) do
    User.create!(username: 'facilities-user', email: 'facilities@example.com', first_name: 'Facilities',
                 last_name: 'User', role: :facilities)
  end
  let(:regular_user) do
    User.create!(username: 'regular-user', email: 'user@example.com', first_name: 'Regular', last_name: 'User')
  end
  let(:other_user) do
    User.create!(username: 'other-user', email: 'other@example.com', first_name: 'Other', last_name: 'User')
  end
  let(:parking_spot) { ParkingSpot.create!(number: 40) }

  let(:own_reservation) { Reservation.new(user: regular_user) }
  let(:others_reservation) { Reservation.new(user: other_user) }
  let(:guest_reservation) do
    GuestReservation.new(parking_spot:, guest_name: 'Guest', guest_license_plate: 'G1')
  end

  describe '#edit?' do
    it 'permits admin on another user\'s reservation' do
      expect(described_class.new(admin, others_reservation).edit?).to eql(true)
    end

    it 'permits facilities on another user\'s reservation' do
      expect(described_class.new(facilities_user, others_reservation).edit?).to eql(true)
    end

    it 'permits facilities on a guest reservation' do
      expect(described_class.new(facilities_user, guest_reservation).edit?).to eql(true)
    end

    it 'permits a regular user on their own reservation' do
      expect(described_class.new(regular_user, own_reservation).edit?).to eql(true)
    end

    it 'forbids a regular user on another user\'s reservation' do
      expect(described_class.new(regular_user, others_reservation).edit?).to eql(false)
    end

    it 'forbids a regular user on a guest reservation' do
      expect(described_class.new(regular_user, guest_reservation).edit?).to eql(false)
    end
  end

  describe '#new_guest?' do
    it 'permits admin and facilities' do
      expect(described_class.new(admin, guest_reservation).new_guest?).to eql(true)
      expect(described_class.new(facilities_user, guest_reservation).new_guest?).to eql(true)
    end

    it 'forbids a regular user' do
      expect(described_class.new(regular_user, guest_reservation).new_guest?).to eql(false)
    end
  end

  describe 'Pundit policy resolution for GuestReservation' do
    it 'resolves to ReservationPolicy without raising' do
      expect(Pundit.policy!(admin, guest_reservation)).to be_a(described_class)
    end
  end

  describe 'Scope' do
    let!(:vehicle) do
      Vehicle.create!(license_plate_number: 'ZH 1', make: 'VW', model: 'Golf', user: regular_user)
    end
    let!(:member_reservation) do
      Reservation.create!(parking_spot:, vehicle:, user: regular_user, date: Date.today)
    end
    let!(:persisted_guest_reservation) do
      second_spot = ParkingSpot.create!(number: 41)
      GuestReservation.create!(parking_spot: second_spot, guest_name: 'Guest', guest_license_plate: 'G1',
                                date: Date.today)
    end

    describe 'for facilities' do
      it 'returns every reservation, including guest ones' do
        scope = described_class::Scope.new(facilities_user, Reservation).resolve
        expect(scope).to include(member_reservation, persisted_guest_reservation)
      end
    end

    describe 'for admin' do
      it 'returns every reservation, including guest ones' do
        scope = described_class::Scope.new(admin, Reservation).resolve
        expect(scope).to include(member_reservation, persisted_guest_reservation)
      end
    end

    describe 'for a regular user' do
      it 'returns only their own reservations, never guest ones' do
        scope = described_class::Scope.new(regular_user, Reservation).resolve
        expect(scope).to include(member_reservation)
        expect(scope).not_to include(persisted_guest_reservation)
      end
    end
  end
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bundle exec rspec spec/policies/reservation_policy_spec.rb`
Expected: FAIL - facilities is forbidden everywhere (`edit?` still checks `admin?` only), `new_guest?` is undefined, and the Scope test for facilities returns only their own reservations.

- [ ] **Step 3: Implement**

Replace `app/policies/reservation_policy.rb` in full:

```ruby
# frozen_string_literal: true

# Authorize access to vehicle resources
class ReservationPolicy < ApplicationPolicy
  # Scoped collection access
  class Scope < Scope
    def resolve
      if user.can_manage_reservations?
        scope.all
      else
        scope.where(user_id: user.id)
      end
    end
  end

  def edit?
    user.can_manage_reservations? || user.id == record.user_id
  end

  def update?
    edit?
  end

  def destroy?
    edit?
  end

  def cancel?
    edit?
  end

  def create?
    edit?
  end

  def new?
    edit?
  end

  def new_guest?
    user.can_manage_reservations?
  end

  def show?
    edit?
  end
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bundle exec rspec spec/policies/reservation_policy_spec.rb`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/policies/reservation_policy.rb spec/policies/reservation_policy_spec.rb
git commit -m "feat: extend ReservationPolicy to facilities and add new_guest? check"
```

---

### Task 7: `ReservationsController#create` - guest support, redirect fix, Slack fix

**Files:**
- Modify: `app/controllers/reservations_controller.rb` (`create`, new private helpers)
- Create: `spec/requests/reservations_html_spec.rb`

**Interfaces:**
- Consumes: `GuestReservation` (Task 3), `ReservationPolicy` (Task 6)
- Produces: `ReservationsController#slack_message_for_reservation(r)` (private, returns a `String`) and `ReservationsController#new_reservation_redirect_path` (private, returns a path `String`) - Task 9 (top-level `cancel`) reuses `slack_message_for_reservation`.

- [ ] **Step 1: Write the failing tests**

Create `spec/requests/reservations_html_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ReservationsController (HTML)', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:facilities_user) do
    User.create!(username: 'facilities-user', email: 'facilities@example.com', first_name: 'Facilities',
                 last_name: 'User', role: :facilities)
  end
  let(:regular_user) do
    User.create!(username: 'regular-user', email: 'user@example.com', first_name: 'Regular', last_name: 'User')
  end
  let!(:vehicle) { Vehicle.create!(license_plate_number: 'ZH 1', make: 'VW', model: 'Golf', user: regular_user) }
  let!(:parking_spot) { ParkingSpot.create!(number: 50) }

  before { allow(SlackHelper).to receive(:send_message) }

  describe 'POST /reservations (guest)' do
    before { sign_in facilities_user }

    it 'creates a GuestReservation and does not raise building the Slack notification' do
      post reservations_path, params: {
        reservations: [
          { reservation: { date: Date.today, parking_spot_id: parking_spot.id,
                            guest_name: 'Jane Guest', guest_license_plate: 'ZH 9999' } }
        ]
      }

      expect(response).to redirect_to(dashboard_path)
      expect(GuestReservation.count).to eq(1)
      expect(GuestReservation.last.guest_name).to eq('Jane Guest')
      expect(GuestReservation.last.created_by).to eq(facilities_user)
      expect(SlackHelper).to have_received(:send_message).with(a_string_including('Jane Guest'))
    end

    it 'redirects back to the guest form, not a UrlGenerationError, when the parking spot no longer exists' do
      post reservations_path, params: {
        reservations: [
          { reservation: { date: Date.today, parking_spot_id: 'does-not-exist',
                            guest_name: 'Jane Guest', guest_license_plate: 'ZH 9999' } }
        ]
      }

      expect(response).to redirect_to(new_guest_reservations_path)
      expect(GuestReservation.count).to eq(0)
    end

    it 'allows a second guest reservation on the same day (bypasses the per-day cap)' do
      second_spot = ParkingSpot.create!(number: 51)

      post reservations_path, params: {
        reservations: [
          { reservation: { date: Date.today, parking_spot_id: parking_spot.id,
                            guest_name: 'Guest One', guest_license_plate: 'G1' } }
        ]
      }
      post reservations_path, params: {
        reservations: [
          { reservation: { date: Date.today, parking_spot_id: second_spot.id,
                            guest_name: 'Guest Two', guest_license_plate: 'G2' } }
        ]
      }

      expect(GuestReservation.count).to eq(2)
    end
  end

  describe 'POST /reservations (registered user, regression)' do
    before { sign_in regular_user }

    it 'still creates a normal Reservation with created_by left nil when booking for themselves' do
      post reservations_path, params: {
        reservations: [
          { reservation: { date: Date.today, parking_spot_id: parking_spot.id,
                            user_id: regular_user.id, vehicle_id: vehicle.id } }
        ]
      }

      expect(Reservation.count).to eq(1)
      expect(Reservation.last).not_to be_a(GuestReservation)
      expect(Reservation.last.created_by).to be_nil
      expect(SlackHelper).to have_received(:send_message).with(a_string_including(regular_user.full_name))
    end
  end
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bundle exec rspec spec/requests/reservations_html_spec.rb`
Expected: FAIL - `GuestReservation.new(reservation_params(row))` never happens (the controller always builds a base `Reservation`, which raises validation errors for missing user/vehicle instead of saving), and the missing-spot redirect raises `ActionController::UrlGenerationError` for the guest params shape.

- [ ] **Step 3: Implement**

In `app/controllers/reservations_controller.rb`, replace the three `new_user_vehicle_reservation_path(params[:user_id], params[:vehicle_id])` call sites and the `create` method body:

```ruby
  def create
    if params[:reservations].nil?
      @reservation = Reservation.new
      authorize @reservation
      respond_to do |format|
        flash[:danger] =
          'Could not reserve. You did not select a parking spot.'
        format.html { redirect_to new_reservation_redirect_path }
      end
      return
    end

    reservations = []

    response_sent = false

    params[:reservations].each do |reservation|
      @reservation = if reservation[:reservation][:guest_name].present?
                        GuestReservation.new(guest_reservation_params(reservation))
                      else
                        Reservation.new(reservation_params(reservation))
                      end
      @reservation.current_user = current_user
      @reservation.created_by = current_user if @reservation.user_id != current_user.id
      authorize @reservation

      parking_spot = ParkingSpot.find_by(id: @reservation.parking_spot_id)

      if parking_spot.nil?
        flash[:danger] = 'The selected parking spot does not exist anymore.'
        redirect_to new_reservation_redirect_path
        response_sent = true
        break
      end

      if parking_spot.archived?
        flash[:danger] = 'The selected parking spot is no longer available for reservation.'
        redirect_to new_reservation_redirect_path
        response_sent = true
        break
      end

      unless @reservation.save
        flash[:danger] = "There was a problem creating the reservations: #{@reservation.errors.full_messages.join(';')}"
        redirect_to dashboard_path
        response_sent = true
        break
      end

      reservations << @reservation
    end

    unless response_sent
      respond_to do |format|
        flash[:success] = 'Reservations were successfully created.'
        format.html { redirect_to dashboard_path }
      end
    end

    message = ":car: <#{user_url(current_user.id)}|#{current_user.full_name}> created the following reservations:"
    reservations.each { |r| message += slack_message_for_reservation(r) }
    SlackHelper.send_message(message)
  end
```

Add these private helpers (near `reservation_params`):

```ruby
  def new_reservation_redirect_path
    if params[:user_id].present?
      new_user_vehicle_reservation_path(params[:user_id], params[:vehicle_id])
    else
      new_guest_reservations_path
    end
  end

  def slack_message_for_reservation(r)
    vehicle_text = r.vehicle ? "<#{vehicle_url(r.vehicle.id)}|#{r.vehicle.license_plate_number}>" : r.guest_license_plate
    owner_text = r.user ? "<#{user_url(r.user.id)}|#{r.user.full_name}>" : "guest: #{r.owner_name}"
    "\n - #{r.date}, #{r.slot_name} on spot <#{parking_spot_url(r.parking_spot.id)}|#{r.parking_spot.number}> with vehicle #{vehicle_text} for #{owner_text}"
  end

  def guest_reservation_params(params)
    params.require(:reservation).permit(
      :date,
      :am,
      :half_day,
      :parking_spot_id,
      :guest_name,
      :guest_license_plate
    )
  end
```

`new_guest_reservations_path` won't resolve until Task 8 adds the route - that's expected; this task's tests already exercise it, so Task 8 is a hard prerequisite before this suite goes green in CI (both land in the same PR).

- [ ] **Step 4: Add the route stub needed for this task's tests to run**

This task's tests reference `new_guest_reservations_path` and `reservations_path`. `reservations_path` already exists; add just enough of the route now so Task 7's tests can pass on their own - Task 8 will build out the real `new_guest` action behind it:

In `config/routes.rb`, change line 40 from `resources :reservations` to:

```ruby
  resources :reservations do
    collection do
      get :new_guest
    end
  end
```

Add a minimal placeholder action so the route resolves (Task 8 replaces this with the real implementation):

```ruby
  def new_guest
    head :not_implemented
  end
```

(Placed in the `public` section of `ReservationsController`, e.g. right after `create`.)

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bundle exec rspec spec/requests/reservations_html_spec.rb`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app/controllers/reservations_controller.rb config/routes.rb spec/requests/reservations_html_spec.rb
git commit -m "feat: support creating GuestReservation via ReservationsController#create"
```

---

### Task 8: `new_guest` action + route + guest-mode `new.html.erb`

**Files:**
- Modify: `app/controllers/reservations_controller.rb` (replace Task 7's placeholder `new_guest` action with the real one), `app/views/reservations/new.html.erb`
- Modify: `spec/requests/reservations_html_spec.rb`

Note: `config/routes.rb` already has the `get :new_guest` route from Task 7 - no routes.rb change in this task.

**Interfaces:**
- Consumes: `GuestReservation` (Task 3), `ReservationPolicy#new_guest?` (Task 6)
- Produces: `new_guest_reservations_path` (route helper) - already depended on by Task 7 and by Task 12 (nav link).

- [ ] **Step 1: Write the failing tests**

Add to `spec/requests/reservations_html_spec.rb`:

```ruby
  describe 'GET /reservations/new_guest' do
    it 'is reachable by facilities' do
      sign_in facilities_user
      get new_guest_reservations_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Guest name')
    end

    it 'is reachable by admin' do
      admin = User.create!(username: 'admin-user', email: 'admin@example.com', first_name: 'Admin',
                            last_name: 'User', role: :admin)
      sign_in admin
      get new_guest_reservations_path

      expect(response).to have_http_status(:success)
    end

    it 'forbids a regular user' do
      sign_in regular_user
      expect { get new_guest_reservations_path }.to raise_error(Pundit::NotAuthorizedError)
    end
  end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bundle exec rspec spec/requests/reservations_html_spec.rb -e "new_guest"`
Expected: FAIL - the placeholder action from Task 7 returns 501, never renders the form.

- [ ] **Step 3: Implement the controller action**

In `app/controllers/reservations_controller.rb`, replace the placeholder `new_guest` action:

```ruby
  def new_guest
    @reservation = GuestReservation.new
    authorize @reservation

    all_spots = ParkingSpot.status_for_user_next_days(nil, ParkitService::RESERVATION_MAX_WEEKS_INTO_THE_FUTURE * 7)
    @parking_spots = {}
    all_spots.each do |week, days|
      @parking_spots[week] = {}
      days.each do |date, spots|
        @parking_spots[week][date] = spots.select { |spot| spot.allowed_vehicle_type == 'car' }
      end
    end

    render :new
  end
```

- [ ] **Step 4: Make `new.html.erb` render in guest mode**

`new.html.erb` is rendered by both `new` (`@user`/`@vehicle` present) and `new_guest` (`@user`/`@vehicle` nil). Replace the user/vehicle badge block near the top:

```erb
        <div class="spectrum-Badge spectrum-Badge--sizeXL spectrum-Badge--accent">
          <svg class="spectrum-Icon spectrum-Icon--sizeXL spectrum-Badge-icon spectrum-Badge-icon" focusable="false" aria-hidden="true">
            <use xlink:href="#spectrum-icon-18-User"/>
          </svg>
          <div class="spectrum-Badge-label"><%= @user.full_name %></div>
        </div>
        <div class="spectrum-Badge spectrum-Badge--sizeXL spectrum-Badge--positive">
          <svg class="spectrum-Icon spectrum-Icon--sizeXL spectrum-Badge-icon spectrum-Badge-icon" focusable="false" aria-hidden="true">
            <use xlink:href="#spectrum-icon-18-Car"/>
          </svg>
          <div class="spectrum-Badge-label"><%= @vehicle.full_title %></div>
        </div>
```

with:

```erb
        <% if @user %>
          <div class="spectrum-Badge spectrum-Badge--sizeXL spectrum-Badge--accent">
            <svg class="spectrum-Icon spectrum-Icon--sizeXL spectrum-Badge-icon spectrum-Badge-icon" focusable="false" aria-hidden="true">
              <use xlink:href="#spectrum-icon-18-User"/>
            </svg>
            <div class="spectrum-Badge-label"><%= @user.full_name %></div>
          </div>
          <div class="spectrum-Badge spectrum-Badge--sizeXL spectrum-Badge--positive">
            <svg class="spectrum-Icon spectrum-Icon--sizeXL spectrum-Badge-icon spectrum-Badge-icon" focusable="false" aria-hidden="true">
              <use xlink:href="#spectrum-icon-18-Car"/>
            </svg>
            <div class="spectrum-Badge-label"><%= @vehicle.full_title %></div>
          </div>
        <% else %>
          <div class="spectrum-Field">
            <label class="spectrum-FieldLabel" for="guest_name">Guest name</label>
            <input type="text" id="guest_name" name="guest_name" class="spectrum-Textfield-input" required>
          </div>
          <div class="spectrum-Field">
            <label class="spectrum-FieldLabel" for="guest_license_plate">License plate</label>
            <input type="text" id="guest_license_plate" name="guest_license_plate" class="spectrum-Textfield-input" required>
          </div>
        <% end %>
```

Replace the `#parking-spot-status` div's data attributes and the week-budget line right below it:

```erb
      <div id="parking-spot-status" data-user="<%= @user.id %>" data-vehicle="<%= @vehicle.id %>">
        <%
          today_class = ' today'
          max_reservations_per_week = current_user.admin? ? 99 : ParkitService::RESERVATION_MAX_RESERVATIONS_PER_WEEK

          @parking_spots.each do |week, days|
            num_existing_reservations = Reservation.active_within_business_week(days.first[0], @user).count
        %>
```

with:

```erb
      <div id="parking-spot-status" <%= @user ? "data-user=\"#{@user.id}\" data-vehicle=\"#{@vehicle.id}\"".html_safe : '' %>>
        <%
          today_class = ' today'
          max_reservations_per_week = current_user.admin? ? 99 : ParkitService::RESERVATION_MAX_RESERVATIONS_PER_WEEK

          @parking_spots.each do |week, days|
            num_existing_reservations = @user ? Reservation.active_within_business_week(days.first[0], @user).count : 0
        %>
```

Guard the `.self` CSS class line (only meaningful when there's a real `@user`):

```erb
                      if reservations.where(user_id: @user.id).count > 0
                        css_class += ' self'
                      end
```

with:

```erb
                      if @user && reservations.where(user_id: @user.id).count > 0
                        css_class += ' self'
                      end
```

Change the form's post target from the nested route to the plain top-level one, since guest mode has no `@user`/`@vehicle` to nest under:

```erb
      <%= form_tag user_vehicle_reservations_path, method: :post, id: 'reservation-form' do |f| %>
```

with:

```erb
      <%= form_tag(@user ? user_vehicle_reservations_path(@user.id, @vehicle.id) : reservations_path, method: :post, id: 'reservation-form') do |f| %>
```

(`user_vehicle_reservations_path` previously worked with zero args only because it was called from a view where Rails infers the nested `:user_id`/`:vehicle_id` from `@user`/`@vehicle` via `polymorphic_path`-style inference through the URL helpers' implicit context - making both branches explicit here removes that implicit dependency and keeps the helper call correct in both modes.)

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bundle exec rspec spec/requests/reservations_html_spec.rb`
Expected: PASS (full file - confirms Task 7's guest-create tests, which depend on this route, also still pass)

- [ ] **Step 6: Manually verify the existing (non-guest) booking page still renders**

Run: `bin/rails server` (with Postgres up), sign in as any existing user, visit `/users/:id/vehicles/:id/reservations/new`, confirm the page renders unchanged (user/vehicle badges, week budget, `.self` styling on a day you've already booked).

- [ ] **Step 7: Commit**

```bash
git add app/controllers/reservations_controller.rb config/routes.rb app/views/reservations/new.html.erb spec/requests/reservations_html_spec.rb
git commit -m "feat: add new_guest action and guest-mode booking form"
```

---

### Task 9: Top-level cancel route - reachable for guest reservations

**Files:**
- Modify: `config/routes.rb`, `app/controllers/reservations_controller.rb` (`cancel`)
- Modify: `spec/requests/reservations_html_spec.rb`

**Interfaces:**
- Consumes: `slack_message_for_reservation` (Task 7)
- Produces: `cancel_reservation_path(id)` (route helper) - Task 10's view fix points every reservation row's Cancel button at this instead of the user-nested path.

- [ ] **Step 1: Write the failing tests**

Add to `spec/requests/reservations_html_spec.rb`:

```ruby
  describe 'PUT /reservations/:id/cancel' do
    let!(:guest_reservation) do
      GuestReservation.create!(parking_spot:, date: Date.today, guest_name: 'Guest', guest_license_plate: 'G1')
    end

    it 'cancels a guest reservation when called by facilities' do
      sign_in facilities_user
      put cancel_reservation_path(guest_reservation.id)

      expect(guest_reservation.reload.cancelled?).to eql(true)
      expect(SlackHelper).to have_received(:send_message).with(a_string_including('guest: Guest'))
    end

    it 'forbids a regular user' do
      sign_in regular_user
      expect { put cancel_reservation_path(guest_reservation.id) }.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  describe 'PUT /users/:user_id/reservations/:reservation_id/cancel (regression)' do
    let!(:member_reservation) do
      Reservation.create!(parking_spot:, vehicle:, user: regular_user, date: Date.today)
    end

    it 'still cancels a registered user\'s own reservation via the nested route' do
      sign_in regular_user
      put user_reservation_cancel_path(regular_user.id, member_reservation.id)

      expect(member_reservation.reload.cancelled?).to eql(true)
    end
  end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bundle exec rspec spec/requests/reservations_html_spec.rb -e "cancel"`
Expected: FAIL - `cancel_reservation_path` is undefined (no top-level cancel route yet).

- [ ] **Step 3: Implement**

In `config/routes.rb`, extend the block added in Task 7:

```ruby
  resources :reservations do
    collection do
      get :new_guest
    end
    member do
      put :cancel
    end
  end
```

In `app/controllers/reservations_controller.rb`, replace the `cancel` action:

```ruby
  def cancel
    @reservation = if params[:user_id].present?
                      User.find(params[:user_id]).reservations.find(params[:reservation_id])
                    else
                      Reservation.find(params[:id])
                    end
    authorize @reservation

    unless @reservation.can_be_cancelled?(current_user)
      respond_to do |format|
        flash[:danger] = 'Only future reservations can be cancelled.'
        format.html { redirect_to dashboard_path }
      end
      return
    end

    @reservation.assign_attributes({
                                     cancelled: true,
                                     cancelled_at: Time.now,
                                     cancelled_by: current_user
                                   })
    if @reservation.save(validate: false)
      respond_to do |format|
        flash[:success] = 'Reservation was successfully cancelled.'
        format.html { redirect_to dashboard_path }
      end

      message = ":trash-can: <#{user_url(current_user.id)}|#{current_user.full_name}> cancelled reservation:"
      message += slack_message_for_reservation(@reservation)
      SlackHelper.send_message(message)
    else
      respond_to do |format|
        flash[:danger] = 'There was a problem cancelling the reservation.'
        format.html { redirect_to dashboard_path }
      end
    end
  end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bundle exec rspec spec/requests/reservations_html_spec.rb`
Expected: PASS (full file)

- [ ] **Step 5: Commit**

```bash
git add config/routes.rb app/controllers/reservations_controller.rb spec/requests/reservations_html_spec.rb
git commit -m "feat: add top-level cancel route reachable for guest reservations"
```

---

### Task 10: Fix `index.html.erb` and `_reservations_table.html.erb` for guest rows

**Files:**
- Modify: `app/views/reservations/index.html.erb:43-44`, `app/views/reservations/_reservations_table.html.erb:28,39,51`
- Modify: `spec/requests/reservations_html_spec.rb`

**Interfaces:**
- Consumes: `Reservation#owner_name` (Task 3), `cancel_reservation_path` (Task 9)

- [ ] **Step 1: Write the failing test**

Add to `spec/requests/reservations_html_spec.rb`:

```ruby
  describe 'GET /reservations (index renders guest rows)' do
    let!(:guest_reservation) do
      GuestReservation.create!(parking_spot:, date: Date.today, guest_name: 'Jane Guest', guest_license_plate: 'ZH 9999')
    end

    it 'renders the index without raising, showing the guest name and plate' do
      sign_in facilities_user

      get reservations_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Jane Guest')
      expect(response.body).to include('ZH 9999')
    end
  end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bundle exec rspec spec/requests/reservations_html_spec.rb -e "renders the index"`
Expected: FAIL with `NoMethodError: undefined method 'full_name' for nil` (raised inside `index.html.erb`'s "Status Today" loop, `reservation.user.full_name`, since today's guest reservation has `user: nil`).

- [ ] **Step 3: Implement - `index.html.erb`**

Replace the "Status Today" grid's reservation block:

```erb
              reservations.each do |reservation|
            %>
              <div style="border: 1px solid var(--spectrum-gray-300); padding: 5px; margin-bottom: 5px;">
              <%= link_to reservation.user.full_name, user_path(reservation.user.id) %><br>
              <%= link_to reservation.vehicle.license_plate_number, vehicle_path(reservation.vehicle.id) %><br>
              <%= reservation.slot_name %>
              </div>
            <% end %>
```

with:

```erb
              reservations.each do |reservation|
            %>
              <div style="border: 1px solid var(--spectrum-gray-300); padding: 5px; margin-bottom: 5px;">
              <% if reservation.user %>
                <%= link_to reservation.owner_name, user_path(reservation.user.id) %><br>
              <% else %>
                <%= reservation.owner_name %><br>
              <% end %>
              <% if reservation.vehicle %>
                <%= link_to reservation.vehicle.license_plate_number, vehicle_path(reservation.vehicle.id) %><br>
              <% else %>
                <%= reservation.guest_license_plate %><br>
              <% end %>
              <%= reservation.slot_name %>
              </div>
            <% end %>
```

- [ ] **Step 4: Implement - `_reservations_table.html.erb`**

Replace the user cell:

```erb
      <% if show_user %>
        <td class="spectrum-Table-cell"><%= link_to reservation.user.full_name, user_path(reservation.user.id) %></td>
      <% end %>
```

with:

```erb
      <% if show_user %>
        <td class="spectrum-Table-cell">
          <% if reservation.user %>
            <%= link_to reservation.owner_name, user_path(reservation.user.id) %>
          <% else %>
            <%= reservation.owner_name %>
          <% end %>
        </td>
      <% end %>
```

Replace the vehicle cell:

```erb
      <td class="spectrum-Table-cell">
        <%= link_to reservation.vehicle.license_plate_number, vehicle_path(reservation.vehicle.id) %>
      </td>
```

with:

```erb
      <td class="spectrum-Table-cell">
        <% if reservation.vehicle %>
          <%= link_to reservation.vehicle.license_plate_number, vehicle_path(reservation.vehicle.id) %>
        <% else %>
          <%= reservation.guest_license_plate %>
        <% end %>
      </td>
```

Replace the Cancel button's path (inside the `show_actions` block):

```erb
              <%= button_to 'Cancel',
                            user_reservation_cancel_path(reservation.user.id, reservation.id),
                            disabled: !reservation_can_be_cancelled,
```

with:

```erb
              <%= button_to 'Cancel',
                            cancel_reservation_path(reservation.id),
                            disabled: !reservation_can_be_cancelled,
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bundle exec rspec spec/requests/reservations_html_spec.rb -e "renders the index"`
Expected: PASS

- [ ] **Step 6: Run the full request suite to confirm no regression**

Run: `bundle exec rspec spec/requests/reservations_html_spec.rb spec/requests/reservations_spec.rb`
Expected: PASS (the second file is the pre-existing API v1 suite, untouched by this task, must stay green)

- [ ] **Step 7: Commit**

```bash
git add app/views/reservations/index.html.erb app/views/reservations/_reservations_table.html.erb spec/requests/reservations_html_spec.rb
git commit -m "fix: render guest reservations safely in index and reservations table views"
```

---

### Task 11: Guest-mode hidden inputs in `main.js`

**Files:**
- Modify: `app/javascript/parking-spot-status/main.js:246-278` (`createHiddenInput`/`submitForm`)

**Interfaces:**
- Consumes: the `#guest_name`/`#guest_license_plate` text inputs added in Task 8, and the `data-user`/`data-vehicle` attributes (present only in non-guest mode, per Task 8's conditional).

No automated JS test infrastructure exists in this repo (no `package.json`, no Jest/webpack config - plain importmap-served vanilla JS). This task's verification step is a manual browser walkthrough, called out explicitly below rather than skipped silently.

- [ ] **Step 1: Implement**

In `app/javascript/parking-spot-status/main.js`, replace `submitForm`:

```js
const submitForm = (event) => {
  event.preventDefault();

  const form = document.getElementById('reservation-form');
  const status = document.getElementById("parking-spot-status");
  const userId = status.getAttribute('data-user');
  const vehicleId = status.getAttribute('data-vehicle');
  const guestNameField = document.getElementById('guest_name');
  const guestLicensePlateField = document.getElementById('guest_license_plate');

  Object.keys(reservations).forEach((date) => {
    const reservation = reservations[date];
    const half_day = reservation.slot === SLOT_NAME_MORNING || reservation.slot === SLOT_NAME_AFTERNOON;
    const am = reservation.slot === SLOT_NAME_MORNING;

    if (userId) {
      form.appendChild(createHiddenInput('user_id', userId));
      form.appendChild(createHiddenInput('vehicle_id', vehicleId));
    } else {
      form.appendChild(createHiddenInput('guest_name', guestNameField.value));
      form.appendChild(createHiddenInput('guest_license_plate', guestLicensePlateField.value));
    }

    form.appendChild(createHiddenInput('parking_spot_id', reservation.parkingSpotId));
    form.appendChild(createHiddenInput('date', date));
    form.appendChild(createHiddenInput('half_day', half_day));
    form.appendChild(createHiddenInput('am', am));
  });

  form.submit();
};
```

`createHiddenInput` itself is unchanged.

- [ ] **Step 2: Manually verify in the browser**

With `bin/rails server` running and Postgres up:

1. Sign in as an admin or facilities user.
2. Visit `/reservations/new_guest`. Confirm the Guest name / License plate fields render instead of the user/vehicle badges.
3. Fill in a name and plate, click an available day's full-day slot, click an available car spot, click Reserve.
4. Confirm you land back on the dashboard with a success flash, and that `GuestReservation.last.guest_name`/`guest_license_plate` match what you typed (check via `bin/rails console` or the `/reservations` index).
5. Repeat step 3 for a different guest on the same day/different spot - confirm it succeeds (no per-day cap error).
6. Visit `/users/:id/vehicles/:id/reservations/new` for a real user and confirm the ordinary booking flow (user/vehicle badges, hidden `user_id`/`vehicle_id` inputs) still works unchanged.

- [ ] **Step 3: Commit**

```bash
git add app/javascript/parking-spot-status/main.js
git commit -m "feat: build guest_name/guest_license_plate hidden inputs in guest booking mode"
```

---

### Task 12: "New guest reservation" nav entry

**Files:**
- Modify: `app/views/layouts/_navigation.html.erb`
- Modify: `spec/requests/reservations_html_spec.rb`

**Interfaces:**
- Consumes: `User#can_manage_reservations?` (Task 1), `new_guest_reservations_path` (Task 8)

- [ ] **Step 1: Write the failing tests**

Add to `spec/requests/reservations_html_spec.rb`:

```ruby
  describe 'navigation' do
    it 'shows the New guest reservation link to facilities' do
      sign_in facilities_user
      get dashboard_path

      expect(response.body).to include('New guest reservation')
    end

    it 'shows the New guest reservation link to admin' do
      admin = User.create!(username: 'admin-user', email: 'admin@example.com', first_name: 'Admin',
                            last_name: 'User', role: :admin)
      sign_in admin
      get dashboard_path

      expect(response.body).to include('New guest reservation')
    end

    it 'hides the New guest reservation link from a regular user' do
      sign_in regular_user
      get dashboard_path

      expect(response.body).not_to include('New guest reservation')
    end
  end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bundle exec rspec spec/requests/reservations_html_spec.rb -e "navigation"`
Expected: FAIL - the link doesn't exist yet, so all three assertions read as if it were hidden (the "shows... to facilities"/"...to admin" cases fail).

- [ ] **Step 3: Implement**

In `app/views/layouts/_navigation.html.erb`, add a new `<li>` as a sibling to the "Dashboard" item (right after its closing `</li>`, before the "Profile" `<li>`), gated to `can_manage_reservations?` so it's visible to both admin and facilities but not folded into the admin-only "Administration" submenu below:

```erb
      <% if current_user.can_manage_reservations? %>
        <li class="spectrum-SideNav-item">
          <a class="spectrum-SideNav-itemLink js-fastLoad" href="<%= new_guest_reservations_path %>">
            <svg class="spectrum-Icon spectrum-Icon--sizeM spectrum-SideNav-itemIcon" focusable="false" aria-hidden="true">
              <use xlink:href="#spectrum-icon-18-Calendar"/>
            </svg>
            New guest reservation
          </a>
        </li>
      <% end %>
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bundle exec rspec spec/requests/reservations_html_spec.rb -e "navigation"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/views/layouts/_navigation.html.erb spec/requests/reservations_html_spec.rb
git commit -m "feat: add New guest reservation nav entry for admin and facilities"
```

---

### Task 13: Full regression pass

**Files:** none (verification only)

- [ ] **Step 1: Run the entire test suite**

Run: `bundle exec rspec`
Expected: PASS, zero failures, zero errors.

- [ ] **Step 2: Run rubocop**

Run: `bundle exec rubocop app/models/reservation.rb app/models/guest_reservation.rb app/models/user.rb app/validators/reservation_validator.rb app/policies/reservation_policy.rb app/controllers/reservations_controller.rb config/routes.rb`
Expected: no new offenses. Fix any that appear before proceeding (do not disable cops to make output green).

- [ ] **Step 3: Confirm `db/schema.rb` is committed and matches a clean `db:migrate` from scratch**

Run: `RAILS_ENV=test bin/rails db:schema:load && bundle exec rspec`
Expected: PASS - proves the migration from Task 2 is sufficient on its own (no manual DB state left over from earlier tasks masking a schema gap).

- [ ] **Step 4: Manual smoke test walkthrough**

Repeat Task 11 Step 2's full walkthrough once more end-to-end on a clean local DB, and additionally:

1. As a plain `user` role, confirm `/reservations/new_guest` redirects/errors with an authorization failure (not a 500).
2. As `admin`, confirm `/reservations` still shows the revenue charts and yearly stats (unchanged for admin).
3. As `facilities`, confirm `/reservations` shows the same charts (per the spec's accepted revenue-visibility exception) and that a guest reservation you just booked appears in "Active Reservations" with a working Cancel button.
4. Cancel that guest reservation via the UI, confirm it moves to "Cancelled Reservations" and the Slack webhook call (check logs/test channel) didn't raise.

- [ ] **Step 5: Final commit (if Steps 2-4 produced any fixes)**

```bash
git add -A
git commit -m "chore: address lint/regression findings from final guest-reservations pass"
```

(Skip this step if nothing needed fixing.)
