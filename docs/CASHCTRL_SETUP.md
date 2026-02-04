# CashCtrl Setup Guide

This guide documents all CashCtrl configuration required for the parking billing system.
Follow these steps for each environment (dev, staging, production).

## Prerequisites

- CashCtrl PRO account
- API key (Settings > API Keys)

## 1. Create Article Category

Navigate to: **Inventory > Categories**

Create a category for parking articles:
- Name: `Parking Fees`
- Type: Article
- Sales Account: Your parking revenue account (e.g., 3400 Dienstleistungsertrag)

Note the **Category ID** for use in article creation.

## 2. Create Parking Articles

Navigate to: **Inventory > Articles**

Create 8 articles in the "Parking Fees" category:

| Article Nr | Name | Price (CHF) |
|------------|------|-------------|
| PARK-CAR-HD-WD | Parking Car Half-Day (Weekday) | 10.00 |
| PARK-CAR-HD-WE | Parking Car Half-Day (Weekend) | 0.00 |
| PARK-CAR-FD-WD | Parking Car Full-Day (Weekday) | 20.00 |
| PARK-CAR-FD-WE | Parking Car Full-Day (Weekend) | 0.00 |
| PARK-MC-HD-WD | Parking Motorcycle Half-Day (Weekday) | 2.50 |
| PARK-MC-HD-WE | Parking Motorcycle Half-Day (Weekend) | 0.00 |
| PARK-MC-FD-WD | Parking Motorcycle Full-Day (Weekday) | 5.00 |
| PARK-MC-FD-WE | Parking Motorcycle Full-Day (Weekend) | 0.00 |

Set Type: **Service** for all articles.

Note the **Article IDs** after creation.

### API Commands (alternative)

```bash
# Set your credentials
API_KEY="your-api-key"
ORG="your-org"
CATEGORY_ID=2  # Your Parking Fees category ID

# Create articles
curl -s -u "${API_KEY}:" -X POST "https://${ORG}.cashctrl.com/api/v1/inventory/article/create.json" \
  -d "categoryId=${CATEGORY_ID}" -d "nr=PARK-CAR-HD-WD" -d "name=Parking Car Half-Day (Weekday)" -d "type=SERVICE"

# ... repeat for each article, then update prices:
curl -s -u "${API_KEY}:" -X POST "https://${ORG}.cashctrl.com/api/v1/inventory/article/update.json" \
  -d "id=ARTICLE_ID" -d "nr=PARK-CAR-HD-WD" -d "name=Parking Car Half-Day (Weekday)" -d "salesPrice=10"
```

## 3. Create Invoice Category

Navigate to: **Settings > Order Categories**

Create a new category:
- Name (singular): `Parking Invoice`
- Name (plural): `Parking Invoices`
- Type: Sales
- Book Type: Debit
- Due Days: 30
- Account: Debtors account (usually 1100)

Add statuses:
1. **Draft** (Gray) - isBook: false
2. **Open** (Blue) - isBook: true
3. **Paid** (Green) - isBook: true, isClosed: true
4. **Cancelled** (Yellow) - isBook: true, isClosed: true

Note the **Category ID** after creation.

### API Command (alternative)

```bash
curl -s -u "${API_KEY}:" -X POST "https://${ORG}.cashctrl.com/api/v1/order/category/create.json" \
  -d "nameSingular=Parking Invoice" \
  -d "namePlural=Parking Invoices" \
  -d "type=SALES" \
  -d "bookType=DEBIT" \
  -d "dueDays=30" \
  -d "accountId=4" \
  -d 'status=[{"name":"Draft","icon":"GRAY","isBook":false},{"name":"Open","icon":"BLUE","isBook":true},{"name":"Paid","icon":"GREEN","isBook":true,"isClosed":true},{"name":"Cancelled","icon":"YELLOW","isBook":true,"isClosed":true}]'
```

## 4. Configure Environment Variables

Set these in your `.env` or Heroku config:

```bash
# CashCtrl connection
CASHCTRL_ORG=your-org-name
CASHCTRL_API_KEY=your-api-key

# Invoice category (from step 3)
CASHCTRL_INVOICE_CATEGORY_ID=1000

# Sales account for line items (from article category salesAccountId)
CASHCTRL_SALES_ACCOUNT_ID=176

# Tax rate ID (1 = MwSt 7.7%, 2 = 3.7%, 3 = 2.5%)
CASHCTRL_TAX_ID=1

# Optional: billing start date
BILLING_START_DATE=2025-01-01

# Article numbers (not IDs!) from step 2
CASHCTRL_ARTIKEL_CAR_HALFDAY_WEEKDAY=PARK-CAR-HD-WD
CASHCTRL_ARTIKEL_CAR_HALFDAY_WEEKEND=PARK-CAR-HD-WE
CASHCTRL_ARTIKEL_CAR_FULLDAY_WEEKDAY=PARK-CAR-FD-WD
CASHCTRL_ARTIKEL_CAR_FULLDAY_WEEKEND=PARK-CAR-FD-WE
CASHCTRL_ARTIKEL_MOTORCYCLE_HALFDAY_WEEKDAY=PARK-MC-HD-WD
CASHCTRL_ARTIKEL_MOTORCYCLE_HALFDAY_WEEKEND=PARK-MC-HD-WE
CASHCTRL_ARTIKEL_MOTORCYCLE_FULLDAY_WEEKDAY=PARK-MC-FD-WD
CASHCTRL_ARTIKEL_MOTORCYCLE_FULLDAY_WEEKEND=PARK-MC-FD-WE
```

## Environment Reference

### Dev (friendsofadobebaseldev)

| Setting | Value |
|---------|-------|
| CASHCTRL_ORG | friendsofadobebaseldev |
| CASHCTRL_INVOICE_CATEGORY_ID | 1000 |
| CASHCTRL_SALES_ACCOUNT_ID | 176 |
| CASHCTRL_TAX_ID | 1 |
| CASHCTRL_ARTIKEL_CAR_HALFDAY_WEEKDAY | PARK-CAR-HD-WD |
| CASHCTRL_ARTIKEL_CAR_HALFDAY_WEEKEND | PARK-CAR-HD-WE |
| CASHCTRL_ARTIKEL_CAR_FULLDAY_WEEKDAY | PARK-CAR-FD-WD |
| CASHCTRL_ARTIKEL_CAR_FULLDAY_WEEKEND | PARK-CAR-FD-WE |
| CASHCTRL_ARTIKEL_MOTORCYCLE_HALFDAY_WEEKDAY | PARK-MC-HD-WD |
| CASHCTRL_ARTIKEL_MOTORCYCLE_HALFDAY_WEEKEND | PARK-MC-HD-WE |
| CASHCTRL_ARTIKEL_MOTORCYCLE_FULLDAY_WEEKDAY | PARK-MC-FD-WD |
| CASHCTRL_ARTIKEL_MOTORCYCLE_FULLDAY_WEEKEND | PARK-MC-FD-WE |

### Production

| Setting | Value |
|---------|-------|
| CASHCTRL_ORG | TBD |
| CASHCTRL_INVOICE_CATEGORY_ID | TBD |
| CASHCTRL_SALES_ACCOUNT_ID | TBD |
| CASHCTRL_TAX_ID | TBD |
| ... | ... |

## Verification

After setup, verify with:

```bash
# List articles
curl -s -u "${API_KEY}:" "https://${ORG}.cashctrl.com/api/v1/inventory/article/list.json"

# List order categories
curl -s -u "${API_KEY}:" "https://${ORG}.cashctrl.com/api/v1/order/category/list.json"
```
