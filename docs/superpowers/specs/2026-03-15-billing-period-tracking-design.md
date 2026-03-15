# Billing Period Tracking Design

## Overview

Add a `BillingPeriod` model to track the state of each month's billing run. One record per month, storing status, result counts, errors, and who executed it. Replaces the stateless billing dashboard with an auditable history.

## Problem

The current billing system has no record of past runs. The admin dashboard shows aggregate stats from Invoice records but doesn't track when billing was executed, by whom, or whether errors occurred. The "Run Billing" dropdown shows all months regardless of billing status.

## Data Model

### billing_periods

| Column | Type | Description |
|--------|------|-------------|
| id | uuid, pk | |
| period_start | date, unique, not null | First day of billed month |
| period_end | date, not null | Last day of billed month |
| status | integer (enum), not null, default 0 | unbilled, in_progress, completed, partially_failed |
| invoices_created | integer, default 0 | Standard user invoices created |
| invoices_skipped | integer, default 0 | Already-invoiced users skipped |
| journal_entries_created | integer, default 0 | Prepaid journal entries created |
| topup_invoices_created | integer, default 0 | Prepaid top-up invoices created |
| exempt_skipped | integer, default 0 | Exempt users skipped |
| errors | jsonb, default [] | Array of error details [{user_id, type, message}] |
| executed_by_id | uuid, fk -> users, nullable | Admin who ran the billing |
| executed_at | datetime, nullable | When the run completed |
| created_at | datetime | |
| updated_at | datetime | |

**Indexes:**
- `period_start` (unique)
- `status`

**Enum values:**
- `unbilled: 0` - Month exists as a record but billing hasn't been run
- `in_progress: 1` - Billing is currently executing
- `completed: 2` - All users processed without errors
- `partially_failed: 3` - Some users failed, others succeeded

## BillingRunner Changes

### Constructor

Add optional `executed_by` parameter:

```ruby
def initialize(period_start, period_end, executed_by: nil)
```

### Run Flow

1. Find or create `BillingPeriod` for the given `period_start`
2. Set status to `in_progress`
3. Execute existing billing logic (unchanged)
4. Update `BillingPeriod` with result counts from `@results`
5. Set status to `completed` if `errors` is empty, `partially_failed` otherwise
6. Set `executed_by_id` and `executed_at`
7. Return results hash (unchanged)

### No changes to:
- `preview` method
- Duplicate prevention logic (uniqueness constraints on Invoice/JournalEntry)
- CashCtrl API calls
- InvoiceLineItemBuilder

## Admin UI Changes

### Dashboard (`GET /admin/billing`)

Replace current stats section with a `BillingPeriod` table (newest first):

| Period | Status | Invoices | Journal Entries | Top-ups | Errors | Executed By | Executed At |
|--------|--------|----------|-----------------|---------|--------|-------------|-------------|

- Status column uses colored badges (green=completed, yellow=partially_failed, gray=unbilled, blue=in_progress)
- Period column links to detail page
- Keep existing action buttons: Run Billing, View Journal Entries, Refresh All Statuses

### Detail Page (`GET /admin/billing_periods/:id`)

Top section: summary stats from BillingPeriod record.

Error section (if any): table of errors with user email and error message.

Invoices section: table of `Invoice.for_period(billing_period.period_start)` with same columns as current invoices index (User, Amount, Status, Sent, Actions).

Back button to dashboard.

### Run Billing Dropdown (`GET /admin/billing/run`)

Filter `available_months_for_billing` to exclude months with a `BillingPeriod` in `completed` status. Months with `partially_failed` remain selectable for retry.

### Routes

Add to existing admin namespace:

```ruby
resources :billing_periods, only: [:show]
```

### Controller

New `Admin::BillingPeriodsController` with `show` action.

Update `Admin::BillingController#execute` to pass `current_user` as `executed_by`.

## Model Relationships

```
BillingPeriod
  belongs_to :executed_by, class_name: 'User', optional: true

User
  has_many :billing_periods_executed, class_name: 'BillingPeriod', foreign_key: :executed_by_id
```

`BillingPeriod` does not have a direct has_many to Invoice. The link is implicit via `period_start` - the detail page queries `Invoice.for_period(billing_period.period_start)`.

## Clarifications

- `executed_at` is set at the END of the run, after all processing and status update
- `BillingPeriod` has no direct association to Invoice - no cascading deletes. If a BillingPeriod record is deleted, invoices remain untouched (they stand on their own)
- Error display on the detail page looks up `User.find(user_id)` for each error entry; deleted users show the raw user_id as fallback

## Out of Scope

- Voiding/undoing a billing run (handle directly in CashCtrl)
- Per-user retry UI (re-running the month automatically picks up failed users)
- Automatic scheduling (remains manual via admin UI)
