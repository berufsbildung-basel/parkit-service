# Guest Reservations Design

## Overview

Let facilities staff (and admins) book parking reservations for people who are not registered users - guests and customers - and let them create multiple such bookings on the same day. Guest reservations are never billed. Implemented as a `GuestReservation < Reservation` subclass (STI) rather than a parallel model, so overlap detection, cancellation, and reporting keep working against a single table with minimal branching.

## Problem

Every `Reservation` currently requires a real, registered `User` (`belongs_to :user`, not-null FK) and a `Vehicle` owned by that user (`belongs_to :user`, not-null FK, unique license plate). `ReservationValidator` also caps every user to `RESERVATION_MAX_RESERVATIONS_PER_DAY` (1) reservation per day. There is no role between `user` and `admin`, so today the only way to book on behalf of someone else is for an `admin` to use the existing (undocumented) "any user_id is a permitted param" mechanism - and that still requires the target to be a real registered `User` with a real `Vehicle`, and still hits the one-per-day cap.

## Roles & Authorization

Add a `facilities` role to the existing enum:

```ruby
enum role: %i[user led_matrix admin facilities]
```

Integer-backed, append-only - no data migration for existing rows.

**Boundary:** `facilities` can book/cancel reservations (their own, other members', and guest), but gets none of the admin-only billing surface.

| Capability | `user` | `facilities` | `admin` |
|---|---|---|---|
| Book own reservation | yes | yes | yes |
| Book/edit reservation for another registered user | no | yes | yes |
| Book a `GuestReservation` | no | yes | yes |
| Cancel any reservation same-day (not just future) | no | yes | yes |
| `Admin::BillingController`, `InvoicesController`, `BillingPeriodsController` | no | no | yes |
| Change user roles | no | no | yes |

**Centralized capability check** (`app/models/user.rb`), added specifically so `admin? || facilities?` isn't hand-repeated (and inevitably drifts) at every call site below and in any future admin-equivalent check:

```ruby
def can_manage_reservations? = admin? || facilities?
```

**Policy changes** (`app/policies/reservation_policy.rb`):

- `edit?`/`create?`: `user.admin? or user.id == record.user_id` → `user.can_manage_reservations? || user.id == record.user_id`. For a `GuestReservation`, `record.user_id` is always nil, so only `can_manage_reservations?` ever satisfies this.
- `Scope#resolve` currently returns `scope.all` only for `user.admin?`, else `scope.where(user_id: user.id)`. Change the condition to `user.can_manage_reservations?`. Without this, facilities would only ever see their own reservations at `/reservations` - not the guest bookings they create, not other members' bookings - contradicting the UI/UX section below, which relies on facilities getting the same index as admin.
- New check gating the guest-booking route/controller action to `can_manage_reservations?` only.

**Model change** (`app/models/reservation.rb`):

```ruby
def can_be_cancelled?(current_user)
  current_user.can_manage_reservations? || start_time > Time.now
end
```

**Unchanged:** `Admin::BaseController#require_admin!` stays `current_user.admin?` - this is what keeps facilities out of billing/invoices/CashCtrl/role management.

## Data Model

### `reservations` table changes

| Column | Type | Change |
|---|---|---|
| `type` | string, nullable | **new** - enables STI. Existing rows get `NULL`, which Rails instantiates as base `Reservation` with no backfill. |
| `user_id` | uuid | **now nullable** (was not-null) |
| `vehicle_id` | uuid | **now nullable** (was not-null) |
| `guest_name` | string, nullable | **new** - required by `GuestReservation`, unused by base `Reservation` |
| `guest_license_plate` | string, nullable | **new** - required by `GuestReservation`, unused by base `Reservation`. No uniqueness constraint - a returning guest can reuse a plate, two same-day guest bookings can share a plate (e.g. carpool). |
| `created_by_id` | uuid, fk -> users, nullable | **new** - set whenever the creator isn't the reservation's owner: any staff-assisted booking (guest or a registered member booked by facilities/admin), not just guest ones. |

No `guest_vehicle_make`/`guest_vehicle_model`/`guest_vehicle_type` - out of scope (see below).

Add indexes on `type` and `created_by_id` - conventional for an STI discriminator column and an FK, cheap at this app's scale.

`created_by_id` is set in `ReservationsController#create`, per reservation, right before save: `reservation.created_by = current_user if reservation.user_id != current_user.id`. `nil != current_user.id` is already true, so this one comparison covers both a guest booking and a facilities/admin staffer booking for a different registered member; stays nil when someone books their own reservation.

### Model

```ruby
class Reservation < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :vehicle, optional: true
  belongs_to :created_by, class_name: 'User', optional: true

  def requires_registered_owner? = true
  def owner_name = user&.full_name

  private

  def set_price
    return unless date.present?
    self.price = weekend?(date) ? 0.0 : standard_price
  end
end

class GuestReservation < Reservation
  validates :guest_name, :guest_license_plate, presence: true
  validate :parking_spot_is_car_type

  def requires_registered_owner? = false
  def owner_name = guest_name

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

`parking_spot_is_car_type` is a hardcoded backend safety net (no `guest_vehicle_type` field exists) behind whatever the guest-booking spot picker already filters to in the UI - a defense-in-depth check, not the primary UX guard.

## Validator Changes (`app/validators/reservation_validator.rb`)

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

def validate_vehicle_belongs_to_user(reservation)
  return unless reservation.requires_registered_owner?
  return unless reservation.vehicle.user.nil? || (reservation.vehicle.user.id != reservation.user.id)
  reservation.errors.add(:vehicle, :does_not_belong_to_reservation_user)
end

def validate_user_does_not_exceed_reservations_per_day(reservation)
  return unless reservation.requires_registered_owner?
  return unless reservation.date.present?
  return unless reservation.user.exceeds_reservations_per_day?(reservation.date, reservation.id)
  reservation.errors.add(:user, :exceeds_max_reservations_per_day)
end
```

`validate_parking_spot_is_not_unavailable` and `validate_overlap` are **not** guarded - they must run for every reservation, guest or not.

### Overlap scope fix (a crash this design introduces, not a pre-existing one)

`Reservation.overlapping_on_date_and_parking_spot` (`app/models/reservation.rb:73-84`) currently does `.where('reservations.user_id NOT IN (?)', user.id)`, called with `reservation.user` from the validator. Today `reservation.user` is never nil - `user_id` is a not-null FK - so this line is unreachable on `main`. It only becomes reachable once this design makes `user_id` nullable and introduces guests, at which point `reservation.user` is `nil` for a `GuestReservation` and `user.id` raises `NoMethodError`. It must be fixed as part of this work:

```ruby
scope :overlapping_on_date_and_parking_spot, lambda { |date, parking_spot, user, start_time, end_time|
  scope = active_on_date(date).includes(:vehicle, :user).where(parking_spot:)
  scope = scope.where('reservations.user_id IS DISTINCT FROM ?', user.id) if user.present?
  scope.where('? <= reservations.end_time AND ? >= reservations.start_time', start_time, end_time)
}
```

**Do not use a plain `where.not(user_id: user.id)` here.** That compiles to `WHERE user_id != '<uuid>'`, and under SQL three-valued logic a row with `user_id IS NULL` (every guest reservation) makes that comparison unknown, not true, so guest rows get silently excluded from the result whenever a *registered* user is the caller. Concretely: a guest already occupies spot S at time T; a registered member then books S at T; the scope is called with the member as `user`, the plain `where.not` drops the guest's NULL row, the overlap check comes back empty, and the member's booking saves on top of the guest's - a real double-booking, in exactly the direction the Testing Plan below claims is rejected. Postgres's `IS DISTINCT FROM` treats `NULL` as a real, comparable value (`NULL IS DISTINCT FROM '<uuid>'` is `true`), which is why it's required here instead.

With `user` nil (guest case), no rows are excluded, so the overlap check correctly runs against *every* existing reservation in that spot/date/time window - including other guest reservations, since STI keeps them in the same table. This is the concrete payoff of choosing STI over a parallel `GuestReservation` table: this one fix (plus the `IS DISTINCT FROM` correction) is the only change needed to make overlap detection guest-aware; a separate table would have needed a cross-table query instead.

## UI/UX

Ground truth: the existing "new reservation" page (`app/views/reservations/new.html.erb` + `app/javascript/parking-spot-status/main.js`) is already a multi-week clickable grid - click a day's AM/PM/FD slot, click a spot, repeat across days, one "Reserve" submits everything as one `POST` with an array of `reservations[][reservation][...]` inputs (this is why `create` iterates `params[:reservations]` today - it's multi-day-in-one-booking, not multi-guest). `ParkingSpot.status_for_user_next_days` doesn't use its `user` argument, so the same grid already renders correctly with no real user in context.

**Facilities books for herself:** no change.

**Facilities books for an existing registered member:** no new UI - already works for admins via `/users/:user_id/vehicles/:vehicle_id/reservations/new`; the policy change above just extends it to `facilities?`.

**Facilities books for a guest:** one new page - the same grid/JS, minus user/vehicle badges, with two plain inputs up top (**Guest name**, **License plate**) filled once per submission, spot filter hardcoded to car-type spots. New top-level nav entry "New guest reservation," visible to `admin?`/`facilities?`, placed next to Dashboard - **not** inside the admin-only Administration section, since facilities must not see billing/users nav either. Click path: nav -> 2 text fields -> click day/slot/spot -> Reserve. Same click count as booking for yourself today, minus the vehicle dropdown. A second guest on the same day means repeating the page once more (each submission's guest_name/license_plate applies to all days/slots selected within that one submission).

**Reservations list (`/reservations`):** facilities get the same index as admins, including revenue charts and yearly stats. This is a conscious revenue-visibility decision, not just view reuse - it's a deliberate exception to the billing-boundary above (facilities end up seeing yearly/per-spot revenue despite having no billing/invoice access), accepted here to avoid building a second view. Cheap to reverse later (hide the revenue partials behind `admin?`) if that answer changes. Requires the `Scope#resolve` change in Roles & Authorization above - without it, facilities would only see their own reservations here, not the guest bookings or other members' bookings this index is meant to show them.

`index.html.erb` and `_reservations_table.html.erb` currently call `reservation.user.full_name`, `reservation.vehicle.license_plate_number`, and build each row's Cancel button from `user_reservation_cancel_path(reservation.user.id, reservation.id)` - all of which are nil/unbuildable for a `GuestReservation`. Update both templates to render `reservation.owner_name` instead of `reservation.user.full_name`, guard the vehicle/license-plate cell (blank or `reservation.guest_license_plate` when `vehicle.nil?`), and build the Cancel button from the new top-level cancel route below instead of the user-nested one.

## Controller & Routing

The existing multi-day grid already builds one hidden-input row per selected day inside the `reservations[]` array it POSTs to the existing `create` route. Guest mode reuses that exact same array shape - each row carries `guest_name`/`guest_license_plate` instead of `user_id`/`vehicle_id`. `ReservationsController#create` branches per row on the *shape* of the row, not on a separate action:

```ruby
reservation = if row[:guest_name].present?
  GuestReservation.new(guest_reservation_params(row))
else
  Reservation.new(reservation_params(row))
end
```

`GET /reservations/new_guest` (`ReservationsController#new_guest`) renders the same `new.html.erb` grid in "no target user" mode (guest name/plate inputs instead of user/vehicle badges, car-type spot filter). It posts to the existing `POST /reservations` route. No new `create` action, no new policy object beyond the `can_manage_reservations?` gate on `new_guest` itself. Declare it as a `collection` route inside (or ahead of) the `resources :reservations` block in `config/routes.rb` - otherwise the default `:id` constraint on the `show` route swallows `/reservations/new_guest` as `id: "new_guest"`.

**Cancellation needs a route that doesn't require a `user_id`.** The only existing cancel route, `PUT /users/:user_id/reservations/:id/cancel`, is nested under a user and `ReservationsController#cancel` loads via `@user = User.find(params[:user_id])` then `@user.reservations.find(...)` - a `GuestReservation` has no `user_id` and belongs to no user's `.reservations`, so it's unreachable through this path. Add a top-level `PUT /reservations/:id/cancel` route/action (`can_manage_reservations?` gated) that loads via `Reservation.find(params[:id])` directly, with no `@user` lookup. Keep the existing nested route working unchanged for non-guest cancellation; the new top-level route is what the updated views (UI/UX above) point their Cancel buttons at for every reservation, guest or not, which also simplifies the view templates to a single code path instead of branching on reservation type.

**`create`'s missing/archived-parking-spot error branch must not assume `user_id`/`vehicle_id` params.** It currently redirects to `new_user_vehicle_reservation_path(params[:user_id], params[:vehicle_id])` on that error; a guest submission has neither param, so this raises `ActionController::UrlGenerationError` instead of showing the intended flash message. Branch on `params[:guest_name].present?` (or equivalently, whether `params[:user_id]` is present) and redirect to `new_guest_reservations_path` for the guest case.

**Both Slack notification builders must not assume a real `user`/`vehicle`.** `create` (post-save) and the new top-level `cancel` action build a Slack message from `r.user.full_name`, `r.user.id`, `r.vehicle.license_plate_number` unconditionally today - the first call on a `GuestReservation` raises `NoMethodError` on the happy path. Both call sites must use `r.owner_name` in place of `r.user.full_name`/`r.user.id`, and use `r.vehicle&.license_plate_number || r.guest_license_plate` in place of the bare `r.vehicle.license_plate_number`.

## Billing & Reporting Impact

- `BillingRunner` (`app/services/billing_runner.rb`) always iterates real `User` records and their `.reservations` association. A `GuestReservation` (`user_id: nil`) is structurally invisible to every billing run - no explicit exclusion flag needed.
- `GuestReservation#set_price` forces `price = 0.0` unconditionally, which is what keeps `Reservation.to_billing_xlsx`'s `TOTAL` row (`app/models/reservation.rb:150`, sums `price` across all reservations with no `user`/`vehicle` scoping) correct without touching that call site.
- The admin index's `@monthly_revenue_chart` and `@yearly_stats` (`app/controllers/reservations_controller.rb:74,84,167`) stay correct for a different reason, not price: both query through `.joins(:vehicle)`, an inner join that excludes any row with `vehicle_id: nil` - i.e. every guest reservation - regardless of price. Guests never reach these aggregates at all.
- Occupancy views (`@occupancy_heatmap`, the spot-availability grid) query `Reservation` without the `.joins(:vehicle)` restriction, so they count reservations regardless of price/user/vehicle - unaffected, and correctly still show guest reservations as occupying a spot.
- Two independent guards keep guests out of billing (no `user` association at all, and `price` forced to 0): this is treated as sufficient without an explicit `billable?` predicate, since the design isn't aware of any code path that bills a reservation without going through a real `User`'s `.reservations` association.

## Testing Plan

Full TDD (test written first for every behavior change below, both positive and negative); existing suite is a hard regression gate before merge.

**Regression (must not change):**
- Registered user still capped at 1 reservation/day (positive: 1st succeeds; negative: 2nd rejected).
- Vehicle-ownership and disabled-user checks still enforced for registered-user reservations.
- Overlap check still rejects two real registered users double-booking the same spot/time, exercised through the fixed scope (proves the nil-guard fix didn't change non-guest behavior).
- Admin-books-for-another-registered-user still works.
- Billing run over a period with zero guest reservations produces identical totals/line-items to before this change.
- `to_billing_xlsx` / revenue chart / yearly stats outputs unchanged when no guest reservations exist in range.

**New behavior (positive + negative):**
- `GuestReservation` validity: positive (name + plate + car spot -> saves); negative (missing name, missing plate, non-car spot -> each rejected with a distinct error).
- Per-day cap: positive (2nd/3rd guest reservation same day by facilities succeeds); negative (registered user, and staff-booked-for-member reservations, still capped at 1 - proves the bypass is guest-scoped only).
- Overlap with nil user: negative (guest vs guest same spot/time rejected; guest vs existing member same spot/time rejected, both directions); positive (non-overlapping guest bookings on the same spot/day succeed).
- Authorization: positive (facilities creates/cancels guest reservations and member reservations); negative (`user` role blocked from the guest-booking route; facilities blocked from `Admin::BillingController`/`InvoicesController`/`BillingPeriodsController`).
- Price: positive (guest price always 0, weekday and weekend); negative/regression (non-guest price calculation - standard weekday rate, 0 on weekends, motorcycle vs car rate - unchanged).
- `ReservationPolicy::Scope`: positive (facilities' `/reservations` index includes other members' and guest reservations, matching what an admin sees, not just facilities' own); negative (a plain `user` role's scope is still restricted to their own reservations).
- Cancellation reachability: positive (a `GuestReservation` is cancellable via the new top-level `PUT /reservations/:id/cancel` route by facilities/admin); negative (a plain `user` role gets a policy rejection on that route, not a lookup crash).
- Notification/redirect safety: positive (creating and cancelling a `GuestReservation` sends its Slack notification without raising, using guest name/plate); positive (submitting the guest-booking form against an archived/missing parking spot redirects to the guest form with the flash message, not a routing error).
- Feature/request spec: nav entry visible only to admin/facilities; guest-booking form submit creates a `GuestReservation`; two different guests booked same day both succeed; the reservations index renders a guest reservation's row (name, license plate, working Cancel button) without error.

## Out of Scope

- `guest_vehicle_make`/`guest_vehicle_model`/`guest_vehicle_type` fields - not needed; guests are car-only, enforced via a hardcoded spot-type check rather than a stored field.
- A narrower (chart-free) reservations index for facilities - explicitly rejected in favor of reusing the existing admin index as-is.
- Any change to the per-week reservation cap (`validate_user_does_not_exceed_reservations_per_week`) - it's already disabled/commented out and untouched by this work.
- Moving any current `admin` users to `facilities` - a follow-up manual data change, not part of this design.
- Editing a guest reservation after creation (changing guest name/plate) - only create and cancel are in scope.
