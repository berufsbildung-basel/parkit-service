# Dev Setup

## Install Ruby
...
## Install Postgres
`brew install postgresql`

## Create Database
`./bin/rails db:create`
`./bin/rails db:migrate`

## Add Sample Data
`./bin/rails db:seed`

## CashCtrl Billing Integration

The app integrates with [CashCtrl](https://cashctrl.com) for invoicing.

### Configuration

Copy `.env.example` to `.env` and configure:

| Variable | Description |
|----------|-------------|
| `CASHCTRL_ORG` | Your CashCtrl subdomain (e.g., `mycompany` from `mycompany.cashctrl.com`) |
| `CASHCTRL_API_KEY` | API key from CashCtrl: Settings > API Keys |
| `CASHCTRL_REVENUE_ACCOUNT_ID` | Account ID for parking revenue in your chart of accounts |
| `BILLING_START_DATE` | Optional. Reservations before this date won't be billed |

### Heroku Deployment

Set environment variables on Heroku:

```bash
heroku config:set \
  CASHCTRL_ORG=your-org-name \
  CASHCTRL_API_KEY=your-api-key \
  CASHCTRL_REVENUE_ACCOUNT_ID=123 \
  BILLING_START_DATE=2025-01-01
```

### Rake Tasks

```bash
# Run billing for previous month
bin/rails billing:run

# Run billing for a specific month
MONTH=2025-01 bin/rails billing:run

# Sync invoice status from CashCtrl
bin/rails billing:sync_status
```

---

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...
