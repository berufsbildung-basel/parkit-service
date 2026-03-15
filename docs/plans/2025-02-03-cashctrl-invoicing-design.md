# CashCtrl Invoicing Integration Design

## Overview

Monthly invoicing system that creates invoices in CashCtrl for parking reservations, with local tracking and an admin interface.

## Key Decisions

| Decision | Choice |
|----------|--------|
| Invoice timing | First of month, for previous completed month |
| Who gets invoiced | Only users with total > 0 CHF |
| CashCtrl person mapping | Hybrid: match by email, create if not found |
| Local tracking | Mirror invoices locally, sync status from CashCtrl |
| QR-bill | Already configured in CashCtrl, automatic |
| Email sending | Through CashCtrl API |
| Payment terms | 30 days |
| Line item detail | One line per reservation |
| Duplicate prevention | Skip already-invoiced users on re-run |
| Cancelled reservations | Include as 0 CHF line items for transparency |
| Historical months | Configurable start date via env var |
| Manual overrides | Handle edge cases directly in CashCtrl |
| Status sync | Daily background job + manual refresh button |
| Invoice language | Use user's `preferred_language` field |
| Billing types | Standard (invoice), Prepaid (journal entries), Exempt (skip) |
| Prepaid accounts | One CashCtrl account per prepaid user |
| Prepaid top-up threshold | Per-user configurable |

## User Billing Types

Three billing types determine how a user's reservations are handled:

### Standard (default)

- Monthly invoice generated in CashCtrl
- One line item per reservation
- This is the default for all users

### Prepaid

- User has prepaid balance in their CashCtrl private account
- Monthly: **journal entries** debit their account (no invoice document)
- When balance drops below user's threshold: **top-up invoice** generated
- Requires linking user to their CashCtrl private account

**User fields for prepaid:**
- `cashctrl_private_account_id` - The CashCtrl account ID (e.g., account 2000.001)
- `prepaid_threshold` - Balance threshold that triggers top-up invoice (e.g., 100.00 CHF)
- `prepaid_topup_amount` - Amount to request on top-up invoice (e.g., 500.00 CHF)

**Monthly process for prepaid users:**
1. Calculate total usage for the month
2. Create journal entry: Debit private account, Credit parking revenue
3. Query current account balance from CashCtrl
4. If balance < threshold → generate top-up invoice

### Exempt

- No billing action taken
- Reservations still tracked and count toward statistics
- Use for: administrative users, corporate bookings, special arrangements

## Environment Configuration

- `CASHCTRL_ORG` - Organization subdomain
- `CASHCTRL_API_KEY` - API key (different per environment)
- `BILLING_START_DATE` - When invoicing begins (e.g., "2025-02-01")
- `CASHCTRL_REVENUE_ACCOUNT_ID` - Parking revenue account for journal entries

**Tenant separation:**
- Local development → CashCtrl Dev tenant
- Heroku production → CashCtrl Prod tenant

## Data Model

### users (additions)

| Column | Type | Description |
|--------|------|-------------|
| billing_type | enum | standard, prepaid, exempt (default: standard) |
| cashctrl_person_id | integer, nullable | CashCtrl person ID (cached after first lookup) |
| cashctrl_private_account_id | integer, nullable | For prepaid users: their private account |
| prepaid_threshold | decimal, nullable | Balance threshold for top-up invoice |
| prepaid_topup_amount | decimal, nullable | Amount to request on top-up |

### invoices

| Column | Type | Description |
|--------|------|-------------|
| id | uuid, pk | |
| user_id | uuid, fk → users | |
| cashctrl_invoice_id | integer, nullable | CashCtrl's invoice ID |
| cashctrl_person_id | integer | CashCtrl's person/customer ID |
| period_start | date | First day of billed month |
| period_end | date | Last day of billed month |
| total_amount | decimal | Total in CHF |
| status | enum | draft, sent, paid, cancelled |
| cashctrl_status | string | Raw status from CashCtrl |
| sent_at | datetime, nullable | When email was sent |
| paid_at | datetime, nullable | When payment received |
| created_at | datetime | |
| updated_at | datetime | |

**Indexes:**
- `user_id`
- `[user_id, period_start]` (unique) - prevents duplicate invoices per user/period
- `cashctrl_invoice_id`
- `status`

### invoice_line_items

| Column | Type | Description |
|--------|------|-------------|
| id | uuid, pk | |
| invoice_id | uuid, fk → invoices | |
| reservation_id | uuid, fk → reservations | |
| description | string | e.g., "15.01.2025 \| Platz #42 \| Ganztag" |
| quantity | integer | Default 1 |
| unit_price | decimal | From reservation.price (0 for cancelled) |
| created_at | datetime | |
| updated_at | datetime | |

### journal_entries (for prepaid users)

| Column | Type | Description |
|--------|------|-------------|
| id | uuid, pk | |
| user_id | uuid, fk → users | |
| cashctrl_journal_id | integer, nullable | CashCtrl's journal entry ID |
| period_start | date | First day of billed month |
| period_end | date | Last day of billed month |
| total_amount | decimal | Total usage in CHF |
| reservation_count | integer | Number of reservations included |
| created_at | datetime | |
| updated_at | datetime | |

**Indexes:**
- `user_id`
- `[user_id, period_start]` (unique) - prevents duplicate entries per user/period
- `cashctrl_journal_id`

## Billing Run Process

**Trigger:** Admin clicks "Run Billing" button

### Steps for a given month:

1. **Validate period**
   - Check `BILLING_START_DATE` - skip if requested month is before start date
   - Confirm the month is complete (can't bill current/future months)

2. **Gather users with reservations**
   - Find all users with reservations for the period
   - Group by `billing_type`

3. **Process by billing type:**

#### Standard users (invoice)
- Exclude users with zero totals
- Exclude users who already have an invoice for this period
- For each eligible user:
  - **CashCtrl person lookup:** Search by email → create if not found → cache `cashctrl_person_id`
  - **Build line items:** One per reservation (including cancelled at 0 CHF)
    - Format: `"15.01.2025 | Platz #42 | Ganztag | Auto"` (localized per user's preferred_language)
  - **Create invoice in CashCtrl:**
    - Associate with person
    - Set 30-day payment terms
    - QR-bill generated automatically by CashCtrl
  - **Store locally:** Create `Invoice` + `InvoiceLineItem` records with CashCtrl reference

#### Prepaid users (journal entry + optional top-up)
- Exclude users who already have a journal entry for this period
- For each prepaid user with reservations:
  - **Calculate total usage** for the month
  - **Create journal entry in CashCtrl:**
    - Debit: User's private account (`cashctrl_private_account_id`)
    - Credit: Parking revenue account
    - Description: "Parkgebühren {month} {year}" (localized)
  - **Store locally:** Create `JournalEntry` record
  - **Check balance:** Query CashCtrl for current account balance
  - **If balance < threshold:** Generate top-up invoice
    - Amount: `prepaid_topup_amount`
    - Single line item: "Aufladung Parkkonto" / "Parking account top-up"

#### Exempt users
- Skip entirely (no action)
- Reservations remain tracked for statistics

4. **Return summary:**
   ```
   Standard: Created 12 invoices, skipped 3 (already invoiced)
   Prepaid: Created 5 journal entries, 2 top-up invoices triggered
   Exempt: 4 users skipped
   Errors: 0
   ```

### Error Handling

If CashCtrl fails mid-run:
- Already-created invoices are safe (stored locally with CashCtrl ID)
- Re-running will skip them and retry failed ones
- Log all errors for debugging

## Admin Interface

### Routes

- `GET /admin/billing` - Billing dashboard
- `GET /admin/billing/run` - Billing run panel
- `POST /admin/billing/run` - Execute billing run
- `GET /admin/invoices` - Invoice list
- `POST /admin/invoices/:id/send_email` - Send invoice email
- `GET /admin/invoices/:id/download_pdf` - Download PDF
- `POST /admin/invoices/:id/refresh_status` - Sync single invoice
- `POST /admin/invoices/refresh_all` - Sync all open invoices
- `GET /admin/journal_entries` - Journal entries list (prepaid users)

### Billing Dashboard

- Summary stats: total open amount, invoices by status, journal entries this month
- Tabs: Invoices, Journal Entries, Prepaid Accounts
- Quick actions: Run Billing, Refresh All Statuses

### Invoice List

- Filters: period (month/year), status (open/paid/all), user search
- Table columns: User, Period, Amount, Status, Sent date, Actions
- Actions per row: View, Send Email, Download PDF, Refresh Status

### Journal Entries List

- Filters: period (month/year), user search
- Table columns: User, Period, Amount, Reservation count, Created date
- Shows prepaid user journal entries for transparency

### Billing Run Panel

- Month/year dropdown (only past months, respecting `BILLING_START_DATE`)
- "Preview Run" button → shows breakdown by billing type:
  - Standard users to invoice (with estimated totals)
  - Prepaid users for journal entries (with amounts)
  - Prepaid users needing top-up (balance below threshold)
  - Exempt users (skipped)
- "Run Billing" button → executes with progress feedback
- Results summary after completion

### User Billing History

On existing user detail view:
- Show billing type badge (Standard / Prepaid / Exempt)
- For standard: invoice history with status, amount, PDF download
- For prepaid: journal entry history + current balance + top-up invoices

## CashCtrl API Integration

### Client

New `CashctrlClient` service class.

**Base URL:** `https://{CASHCTRL_ORG}.cashctrl.com/api/v1`

**Authentication:** HTTP Basic Auth with API key

### Endpoints

| Operation | Endpoint |
|-----------|----------|
| Find person | `GET /person/list.json?query={email}` |
| Create person | `POST /person/create.json` |
| Create invoice | `POST /order/create.json` |
| Get invoice | `GET /order/read.json?id={id}` |
| Send email | `POST /order/send-email.json` |
| Download PDF | `GET /order/document.json?id={id}` |
| List invoices | `GET /order/list.json` |
| Create journal entry | `POST /journal/create.json` |
| Get account balance | `GET /account/balance.json?id={id}` |
| List accounts | `GET /account/list.json` |

### Invoice Creation Payload

```ruby
{
  associateId: cashctrl_person_id,
  categoryId: invoice_category_id,  # Configured in CashCtrl
  date: Date.today,
  dueDays: 30,
  items: [
    { name: "15.01.2025 | Platz #42 | Ganztag", unitPrice: 20.0 },
    { name: "16.01.2025 | Platz #12 | Storniert", unitPrice: 0.0 },
  ]
}
```

### Journal Entry Payload (for prepaid users)

```ruby
{
  dateAdded: Date.today,
  items: [
    {
      accountId: user.cashctrl_private_account_id,  # Debit private account
      debit: total_amount
    },
    {
      accountId: parking_revenue_account_id,  # Credit revenue
      credit: total_amount
    }
  ],
  notes: "Parkgebühren Januar 2025 - 8 Reservierungen"
}
```

### Top-up Invoice Payload

```ruby
{
  associateId: cashctrl_person_id,
  categoryId: invoice_category_id,
  date: Date.today,
  dueDays: 30,
  items: [
    { name: "Aufladung Parkkonto", unitPrice: user.prepaid_topup_amount }
  ]
}
```

## Background Jobs

### Daily Invoice Status Sync

- Runs daily (via Heroku Scheduler)
- Fetches status for all non-paid invoices from CashCtrl
- Updates local `status`, `cashctrl_status`, `paid_at` fields

## Out of Scope (YAGNI)

These are handled directly in CashCtrl, not in the app:

- Automatic payment reconciliation (bank import)
- Dispute handling / credit notes
- Custom invoice templates
- Payment reminders
- Detailed accounting reports

## Localization

Line item descriptions use the user's `preferred_language`:

| Language | Example |
|----------|---------|
| de | "15.01.2025 \| Platz #42 \| Ganztag \| Auto" |
| en | "15.01.2025 \| Spot #42 \| Full day \| Car" |
| fr | "15.01.2025 \| Place #42 \| Journée \| Voiture" |
| it | "15.01.2025 \| Posto #42 \| Giornata \| Auto" |

Cancelled reservations show "(Storniert)" / "(Cancelled)" / "(Annulé)" / "(Annullato)" suffix.

### Additional localized strings

| Key | de | en | fr | it |
|-----|----|----|----|----|
| Journal entry description | "Parkgebühren {month} {year}" | "Parking fees {month} {year}" | "Frais de parking {month} {year}" | "Spese parcheggio {month} {year}" |
| Top-up line item | "Aufladung Parkkonto" | "Parking account top-up" | "Rechargement compte parking" | "Ricarica conto parcheggio" |
