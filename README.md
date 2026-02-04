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
| `CASHCTRL_INVOICE_CATEGORY_ID` | Invoice category ID (determines numbering and accounts) |
| `BILLING_START_DATE` | Optional. Reservations before this date won't be billed |

#### Artikel Configuration

Prices are controlled in CashCtrl via Artikel (articles). Create 8 Artikel in CashCtrl for each parking type:

| Env Variable | Description |
|--------------|-------------|
| `CASHCTRL_ARTIKEL_CAR_HALFDAY_WEEKDAY` | Car half-day weekday |
| `CASHCTRL_ARTIKEL_CAR_HALFDAY_WEEKEND` | Car half-day weekend |
| `CASHCTRL_ARTIKEL_CAR_FULLDAY_WEEKDAY` | Car full-day weekday |
| `CASHCTRL_ARTIKEL_CAR_FULLDAY_WEEKEND` | Car full-day weekend |
| `CASHCTRL_ARTIKEL_MOTORCYCLE_HALFDAY_WEEKDAY` | Motorcycle half-day weekday |
| `CASHCTRL_ARTIKEL_MOTORCYCLE_HALFDAY_WEEKEND` | Motorcycle half-day weekend |
| `CASHCTRL_ARTIKEL_MOTORCYCLE_FULLDAY_WEEKDAY` | Motorcycle full-day weekday |
| `CASHCTRL_ARTIKEL_MOTORCYCLE_FULLDAY_WEEKEND` | Motorcycle full-day weekend |

### Heroku Deployment

Set environment variables on Heroku:

```bash
heroku config:set \
  CASHCTRL_ORG=your-org-name \
  CASHCTRL_API_KEY=your-api-key \
  CASHCTRL_INVOICE_CATEGORY_ID=1 \
  CASHCTRL_ARTIKEL_CAR_HALFDAY_WEEKDAY=3 \
  CASHCTRL_ARTIKEL_CAR_HALFDAY_WEEKEND=4 \
  CASHCTRL_ARTIKEL_CAR_FULLDAY_WEEKDAY=5 \
  CASHCTRL_ARTIKEL_CAR_FULLDAY_WEEKEND=6 \
  CASHCTRL_ARTIKEL_MOTORCYCLE_HALFDAY_WEEKDAY=7 \
  CASHCTRL_ARTIKEL_MOTORCYCLE_HALFDAY_WEEKEND=8 \
  CASHCTRL_ARTIKEL_MOTORCYCLE_FULLDAY_WEEKDAY=9 \
  CASHCTRL_ARTIKEL_MOTORCYCLE_FULLDAY_WEEKEND=10
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
