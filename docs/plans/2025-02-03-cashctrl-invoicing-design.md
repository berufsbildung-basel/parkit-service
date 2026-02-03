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

## Environment Configuration

- `CASHCTRL_ORG` - Organization subdomain
- `CASHCTRL_API_KEY` - API key (different per environment)
- `BILLING_START_DATE` - When invoicing begins (e.g., "2025-02-01")

**Tenant separation:**
- Local development → CashCtrl Dev tenant
- Heroku production → CashCtrl Prod tenant

## Data Model

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

## Invoice Run Process

**Trigger:** Admin clicks "Run Invoice Generation" button

### Steps for a given month:

1. **Validate period**
   - Check `BILLING_START_DATE` - skip if requested month is before start date
   - Confirm the month is complete (can't invoice current/future months)

2. **Gather eligible users**
   - Find all users with non-zero reservation totals for the period
   - Exclude users who already have an invoice for this period

3. **For each eligible user:**
   - **CashCtrl person lookup:** Search by email → create if not found → store `cashctrl_person_id`
   - **Build line items:** One per reservation (including cancelled at 0 CHF)
     - Format: `"15.01.2025 | Platz #42 | Ganztag | Auto"` (localized per user's preferred_language)
   - **Create invoice in CashCtrl:**
     - Associate with person
     - Set 30-day payment terms
     - QR-bill generated automatically by CashCtrl
   - **Store locally:** Create `Invoice` + `InvoiceLineItem` records with CashCtrl reference

4. **Return summary:** "Created 12 invoices, skipped 3 (already invoiced), 0 errors"

### Error Handling

If CashCtrl fails mid-run:
- Already-created invoices are safe (stored locally with CashCtrl ID)
- Re-running will skip them and retry failed ones
- Log all errors for debugging

## Admin Interface

### Routes

- `GET /admin/invoices` - Invoice dashboard
- `GET /admin/invoices/new` - Invoice run panel
- `POST /admin/invoices/run` - Execute invoice run
- `POST /admin/invoices/:id/send_email` - Send invoice email
- `GET /admin/invoices/:id/download_pdf` - Download PDF
- `POST /admin/invoices/:id/refresh_status` - Sync single invoice
- `POST /admin/invoices/refresh_all` - Sync all open invoices

### Invoice Dashboard (index)

- Summary stats: total open amount, invoices by status
- Filters: period (month/year), status (open/paid/all), user search
- Table columns: User, Period, Amount, Status, Sent date, Actions
- Actions per row: View, Send Email, Download PDF, Refresh Status

### Invoice Run Panel

- Month/year dropdown (only past months, respecting `BILLING_START_DATE`)
- "Preview Run" button → shows who would be invoiced and estimated totals
- "Run Invoice Generation" button → executes with progress feedback
- Results summary after completion

### User Invoice History

On existing user billing view (`/users/:id/billing`):
- Show invoice history with status, amount, PDF download links

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
