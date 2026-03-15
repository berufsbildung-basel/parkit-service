# Prepaid Statement Invoice Design

## Overview

Replace the current prepaid billing flow (journal entry + separate top-up invoice) with a single statement invoice per month. This is a new invoicing model - not a refactor of the existing journal entry approach. The statement shows the opening balance, individual bookings, and a total that reflects the amount owed or credit remaining.

## Problem

The current prepaid flow creates a journal entry to debit the user's private CashCtrl account, then checks if a separate top-up invoice is needed. This is opaque to the user - they never see a statement of their account. The new approach creates a transparent invoice that doubles as both statement and payment request.

## Design

### Statement Invoice Structure

Each prepaid user gets one CashCtrl invoice per month (enforced by unique index on `[user_id, period_start]`) with these line items:

1. **Opening balance line** - "Vortrag per DD.MM.YYYY / Balance carried forward"
   - Unit price = inverted CashCtrl account balance (negative balance becomes positive amount owed, positive balance becomes negative credit)
   - No artikel_nr, no reservation_id (informational line)

2. **Booking lines** - Same as standard users: one line per reservation
   - Format: "DD.MM.YYYY | Platz #N | Duration | Vehicle"
   - Uses existing InvoiceLineItemBuilder
   - Cancelled reservations at CHF 0

### Total Interpretation

- **Positive total** = user owes money. QR payment slip shows amount.
- **Negative or zero total** = user has credit. QR payment slip amount left empty (CashCtrl handles this via settings: "leave amount empty in QR invoice").

### Example: User Owes Money

CashCtrl account balance: -130 (user owes 130)

| # | Description | Price | Total |
|---|-------------|-------|-------|
| 1 | Vortrag per 01.01.2026 | 130.00 | 130.00 |
| 2 | 27.01.2026 \| Platz #5 \| Vormittag \| Auto | 10.00 | 10.00 |
| | **Total** | **CHF** | **140.00** |

### Example: User Has Credit

CashCtrl account balance: +500 (user has credit)

| # | Description | Price | Total |
|---|-------------|-------|-------|
| 1 | Vortrag per 01.01.2026 | -500.00 | -500.00 |
| 2 | 27.01.2026 \| Platz #5 \| Vormittag \| Auto | 10.00 | 10.00 |
| | **Total** | **CHF** | **-490.00** |

## Required Schema Change

### InvoiceLineItem.reservation_id Must Be Nullable

The opening balance line has no associated reservation. Currently `reservation_id` is `NOT NULL` with a required `belongs_to :reservation`.

**Migration:** Change `reservation_id` to nullable.

**Model change:** Add `optional: true` to the `belongs_to :reservation` association in InvoiceLineItem.

## BillingRunner Changes

### process_prepaid_user (replaces current implementation)

1. Check skip: `Invoice.exists?(user, period_start)` (same duplicate check as standard users, replaces JournalEntry check)
2. Fetch opening balance: `client.get_account_balance(user.cashctrl_private_account_id)`
   - If the balance API call fails, record the error and skip this user (same error handling pattern as other API failures)
3. Build booking line items (same as standard users)
4. Invert balance for the opening line: `opening_amount = -balance` (CashCtrl negative = user owes = positive on invoice)
5. Build CashCtrl invoice items: opening balance line + booking lines
6. Create CashCtrl invoice via API
7. Create local Invoice record + InvoiceLineItems (including the balance line with `reservation_id: nil`)

### Edge Cases

- **User with balance but no reservations:** Still gets a statement invoice showing just the balance line. The `total <= 0` skip check is removed for prepaid users - they always get a statement if they have a non-zero balance or reservations.
- **Balance API failure:** Error is recorded in BillingPeriod.errors_log, user is skipped, billing continues for other users.
- **Re-run after reset:** Same as standard users - if Invoice record was deleted, user is re-processed on next run.

### What Gets Removed

- `create_journal_entry` CashCtrl API call for prepaid users
- `check_and_create_topup_invoice` method
- JournalEntry creation for new billing runs
- `topup_invoices_created` counter in BillingRunner results (prepaid users now contribute to `invoices_created`)
- The separate prepaid skip logic based on JournalEntry existence
- The `total <= 0` skip check for prepaid users (they always get a statement)

### What Stays

- JournalEntry model (keep for historical data, no new entries created)
- JournalEntry admin view (for viewing historical entries)
- `cashctrl_private_account_id` on User (needed for balance lookup)
- `prepaid_threshold` and `prepaid_topup_amount` on User (no longer used, but keep for now)

## CashctrlClient Fix

The `get_account_balance` method uses the wrong endpoint:

- Current (broken): `GET /account/balance.json` (returns 404)
- Correct: `GET /account/balance` (per CashCtrl API docs, confirmed via WebFetch)

Also update the corresponding test stub URL.

## BillingPeriod Impact

The `topup_invoices_created` and `journal_entries_created` columns on BillingPeriod become unused for new runs. Prepaid users now contribute to `invoices_created` instead. The columns stay (no migration needed) but will always be 0 for new billing runs.

## Duplicate Prevention

Prepaid users now use the same duplicate check as standard users: `Invoice.exists?(user, period_start)`. The unique index on `[user_id, period_start]` prevents duplicates at the database level. Only one statement invoice per prepaid user per month.

## Out of Scope

- Removing JournalEntry model or admin views (keep for historical data)
- Removing prepaid_threshold/prepaid_topup_amount columns
- Changing the CashCtrl account structure
- Automatic payment reconciliation
