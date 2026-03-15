# CashCtrl Billing Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a monthly billing system that handles three billing types: Standard (invoices), Prepaid (journal entries), and Exempt (skip). Integrates with CashCtrl for Swiss accounting.

**Architecture:** Rails service objects for CashCtrl API integration, ActiveRecord models for local billing storage, Turbo-powered admin views for billing management. TDD with RSpec.

**Tech Stack:** Rails 7.1, PostgreSQL, CashCtrl REST API, Turbo/Stimulus, RSpec

---

## Phase 1: Database & Models

### Task 1: Add Billing Fields to Users

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_add_billing_fields_to_users.rb`

**Step 1: Generate migration**

Run: `rails generate migration AddBillingFieldsToUsers`

**Step 2: Write migration**

```ruby
# frozen_string_literal: true

class AddBillingFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :billing_type, :integer, null: false, default: 0
    add_column :users, :cashctrl_person_id, :integer
    add_column :users, :cashctrl_private_account_id, :integer
    add_column :users, :prepaid_threshold, :decimal, precision: 10, scale: 2
    add_column :users, :prepaid_topup_amount, :decimal, precision: 10, scale: 2

    add_index :users, :billing_type
    add_index :users, :cashctrl_person_id
  end
end
```

**Step 3: Run migration**

Run: `rails db:migrate`
Expected: Migration completes successfully

**Step 4: Update User model**

Add to `app/models/user.rb`:

```ruby
enum billing_type: { standard: 0, prepaid: 1, exempt: 2 }

scope :billable, -> { where(billing_type: [:standard, :prepaid]) }
scope :standard_billing, -> { where(billing_type: :standard) }
scope :prepaid_billing, -> { where(billing_type: :prepaid) }
scope :exempt_billing, -> { where(billing_type: :exempt) }
```

**Step 5: Commit**

```bash
git add db/migrate/*_add_billing_fields_to_users.rb db/schema.rb app/models/user.rb
git commit -m "db: add billing_type and CashCtrl fields to users"
```

---

### Task 2: Create Invoice Migration

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_create_invoices.rb`

**Step 1: Generate migration**

Run: `rails generate migration CreateInvoices`

**Step 2: Write migration**

```ruby
# frozen_string_literal: true

class CreateInvoices < ActiveRecord::Migration[7.1]
  def change
    create_table :invoices, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.integer :cashctrl_invoice_id
      t.integer :cashctrl_person_id, null: false
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.decimal :total_amount, precision: 10, scale: 2, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.string :cashctrl_status
      t.datetime :sent_at
      t.datetime :paid_at

      t.timestamps
    end

    add_index :invoices, :cashctrl_invoice_id
    add_index :invoices, :status
    add_index :invoices, [:user_id, :period_start], unique: true
  end
end
```

**Step 3: Run migration**

Run: `rails db:migrate`
Expected: Migration completes successfully

**Step 4: Commit**

```bash
git add db/migrate/*_create_invoices.rb db/schema.rb
git commit -m "db: add invoices table"
```

---

### Task 3: Create InvoiceLineItem Migration

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_create_invoice_line_items.rb`

**Step 1: Generate migration**

Run: `rails generate migration CreateInvoiceLineItems`

**Step 2: Write migration**

```ruby
# frozen_string_literal: true

class CreateInvoiceLineItems < ActiveRecord::Migration[7.1]
  def change
    create_table :invoice_line_items, id: :uuid do |t|
      t.references :invoice, null: false, foreign_key: true, type: :uuid
      t.references :reservation, null: false, foreign_key: true, type: :uuid
      t.string :description, null: false
      t.integer :quantity, null: false, default: 1
      t.decimal :unit_price, precision: 10, scale: 2, null: false

      t.timestamps
    end
  end
end
```

**Step 3: Run migration**

Run: `rails db:migrate`
Expected: Migration completes successfully

**Step 4: Commit**

```bash
git add db/migrate/*_create_invoice_line_items.rb db/schema.rb
git commit -m "db: add invoice_line_items table"
```

---

### Task 4: Create JournalEntry Migration

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_create_journal_entries.rb`

**Step 1: Generate migration**

Run: `rails generate migration CreateJournalEntries`

**Step 2: Write migration**

```ruby
# frozen_string_literal: true

class CreateJournalEntries < ActiveRecord::Migration[7.1]
  def change
    create_table :journal_entries, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.integer :cashctrl_journal_id
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.decimal :total_amount, precision: 10, scale: 2, null: false, default: 0
      t.integer :reservation_count, null: false, default: 0

      t.timestamps
    end

    add_index :journal_entries, :cashctrl_journal_id
    add_index :journal_entries, [:user_id, :period_start], unique: true
  end
end
```

**Step 3: Run migration**

Run: `rails db:migrate`
Expected: Migration completes successfully

**Step 4: Commit**

```bash
git add db/migrate/*_create_journal_entries.rb db/schema.rb
git commit -m "db: add journal_entries table for prepaid users"
```

---

### Task 5: Create Invoice Model with Tests

**Files:**
- Create: `spec/models/invoice_spec.rb`
- Create: `app/models/invoice.rb`

**Step 1: Write failing tests**

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Invoice, type: :model do
  let(:user) do
    User.create!(
      username: 'test-user',
      email: 'test@example.com',
      first_name: 'Test',
      last_name: 'User'
    )
  end

  describe 'validations' do
    it 'requires user' do
      invoice = Invoice.new(
        cashctrl_person_id: 123,
        period_start: Date.new(2025, 1, 1),
        period_end: Date.new(2025, 1, 31)
      )
      expect(invoice).not_to be_valid
      expect(invoice.errors[:user]).to include("must exist")
    end

    it 'requires cashctrl_person_id' do
      invoice = Invoice.new(
        user: user,
        period_start: Date.new(2025, 1, 1),
        period_end: Date.new(2025, 1, 31)
      )
      expect(invoice).not_to be_valid
      expect(invoice.errors[:cashctrl_person_id]).to include("can't be blank")
    end

    it 'enforces unique user/period_start combination' do
      Invoice.create!(
        user: user,
        cashctrl_person_id: 123,
        period_start: Date.new(2025, 1, 1),
        period_end: Date.new(2025, 1, 31)
      )

      duplicate = Invoice.new(
        user: user,
        cashctrl_person_id: 123,
        period_start: Date.new(2025, 1, 1),
        period_end: Date.new(2025, 1, 31)
      )
      expect(duplicate).not_to be_valid
    end
  end

  describe 'status enum' do
    it 'has expected statuses' do
      expect(Invoice.statuses.keys).to eq(%w[draft sent paid cancelled])
    end
  end

  describe 'associations' do
    it 'belongs to user' do
      invoice = Invoice.new
      expect(invoice).to respond_to(:user)
    end

    it 'has many line_items' do
      invoice = Invoice.new
      expect(invoice).to respond_to(:line_items)
    end
  end

  describe 'scopes' do
    let!(:draft_invoice) do
      Invoice.create!(user: user, cashctrl_person_id: 1, period_start: Date.new(2025, 1, 1), period_end: Date.new(2025, 1, 31), status: :draft)
    end
    let!(:paid_invoice) do
      Invoice.create!(user: user, cashctrl_person_id: 1, period_start: Date.new(2025, 2, 1), period_end: Date.new(2025, 2, 28), status: :paid)
    end

    it 'filters open invoices' do
      expect(Invoice.open).to include(draft_invoice)
      expect(Invoice.open).not_to include(paid_invoice)
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/models/invoice_spec.rb`
Expected: FAIL - Invoice model doesn't exist

**Step 3: Create Invoice model**

```ruby
# frozen_string_literal: true

class Invoice < ApplicationRecord
  belongs_to :user
  has_many :line_items, class_name: 'InvoiceLineItem', dependent: :destroy

  enum status: { draft: 0, sent: 1, paid: 2, cancelled: 3 }

  validates :cashctrl_person_id, presence: true
  validates :period_start, presence: true
  validates :period_end, presence: true
  validates :user_id, uniqueness: { scope: :period_start }

  scope :open, -> { where(status: [:draft, :sent]) }
  scope :for_period, ->(start_date) { where(period_start: start_date) }
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/invoice_spec.rb`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add spec/models/invoice_spec.rb app/models/invoice.rb
git commit -m "feat: add Invoice model with validations and scopes"
```

---

### Task 6: Create InvoiceLineItem Model with Tests

**Files:**
- Create: `spec/models/invoice_line_item_spec.rb`
- Create: `app/models/invoice_line_item.rb`

**Step 1: Write failing tests**

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvoiceLineItem, type: :model do
  let(:user) do
    User.create!(username: 'test', email: 'test@example.com', first_name: 'Test', last_name: 'User')
  end
  let(:parking_spot) { ParkingSpot.create!(number: 1) }
  let(:vehicle) { Vehicle.create!(user: user, license_plate_number: 'ZH 123', make: 'Test', model: 'Car') }
  let(:reservation) do
    Reservation.create!(user: user, vehicle: vehicle, parking_spot: parking_spot, date: Date.today + 1.day)
  end
  let(:invoice) do
    Invoice.create!(user: user, cashctrl_person_id: 123, period_start: Date.new(2025, 1, 1), period_end: Date.new(2025, 1, 31))
  end

  describe 'validations' do
    it 'requires invoice' do
      item = InvoiceLineItem.new(reservation: reservation, description: 'Test', unit_price: 20)
      expect(item).not_to be_valid
    end

    it 'requires description' do
      item = InvoiceLineItem.new(invoice: invoice, reservation: reservation, unit_price: 20)
      expect(item).not_to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to invoice' do
      item = InvoiceLineItem.new
      expect(item).to respond_to(:invoice)
    end

    it 'belongs to reservation' do
      item = InvoiceLineItem.new
      expect(item).to respond_to(:reservation)
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/models/invoice_line_item_spec.rb`
Expected: FAIL

**Step 3: Create model**

```ruby
# frozen_string_literal: true

class InvoiceLineItem < ApplicationRecord
  belongs_to :invoice
  belongs_to :reservation

  validates :description, presence: true
  validates :unit_price, presence: true
end
```

**Step 4: Run tests**

Run: `bundle exec rspec spec/models/invoice_line_item_spec.rb`
Expected: PASS

**Step 5: Commit**

```bash
git add spec/models/invoice_line_item_spec.rb app/models/invoice_line_item.rb
git commit -m "feat: add InvoiceLineItem model"
```

---

### Task 7: Create JournalEntry Model with Tests

**Files:**
- Create: `spec/models/journal_entry_spec.rb`
- Create: `app/models/journal_entry.rb`

**Step 1: Write failing tests**

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JournalEntry, type: :model do
  let(:user) do
    User.create!(
      username: 'prepaid-user',
      email: 'prepaid@example.com',
      first_name: 'Prepaid',
      last_name: 'User',
      billing_type: :prepaid,
      cashctrl_private_account_id: 12345
    )
  end

  describe 'validations' do
    it 'requires user' do
      entry = JournalEntry.new(
        period_start: Date.new(2025, 1, 1),
        period_end: Date.new(2025, 1, 31)
      )
      expect(entry).not_to be_valid
      expect(entry.errors[:user]).to include("must exist")
    end

    it 'enforces unique user/period_start combination' do
      JournalEntry.create!(
        user: user,
        period_start: Date.new(2025, 1, 1),
        period_end: Date.new(2025, 1, 31),
        total_amount: 100,
        reservation_count: 5
      )

      duplicate = JournalEntry.new(
        user: user,
        period_start: Date.new(2025, 1, 1),
        period_end: Date.new(2025, 1, 31)
      )
      expect(duplicate).not_to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to user' do
      entry = JournalEntry.new
      expect(entry).to respond_to(:user)
    end
  end

  describe 'scopes' do
    let!(:entry) do
      JournalEntry.create!(
        user: user,
        period_start: Date.new(2025, 1, 1),
        period_end: Date.new(2025, 1, 31),
        total_amount: 100,
        reservation_count: 5
      )
    end

    it 'filters by period' do
      expect(JournalEntry.for_period(Date.new(2025, 1, 1))).to include(entry)
      expect(JournalEntry.for_period(Date.new(2025, 2, 1))).not_to include(entry)
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/models/journal_entry_spec.rb`
Expected: FAIL - JournalEntry model doesn't exist

**Step 3: Create JournalEntry model**

```ruby
# frozen_string_literal: true

class JournalEntry < ApplicationRecord
  belongs_to :user

  validates :period_start, presence: true
  validates :period_end, presence: true
  validates :user_id, uniqueness: { scope: :period_start }

  scope :for_period, ->(start_date) { where(period_start: start_date) }
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/journal_entry_spec.rb`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add spec/models/journal_entry_spec.rb app/models/journal_entry.rb
git commit -m "feat: add JournalEntry model for prepaid user billing"
```

---

### Task 8: Add User Associations for Billing

**Files:**
- Modify: `app/models/user.rb`

**Step 1: Add associations**

Add to `app/models/user.rb`:

```ruby
has_many :invoices, dependent: :destroy
has_many :journal_entries, dependent: :destroy
```

**Step 2: Commit**

```bash
git add app/models/user.rb
git commit -m "feat: add invoices and journal_entries associations to User"
```

---

## Phase 2: CashCtrl API Client

### Task 9: Add Environment Configuration

**Files:**
- Modify: `config/application.yml` (add example)
- Create: `config/initializers/cashctrl.rb`

**Step 1: Add Figaro config example**

Add to `config/application.yml`:

```yaml
# CashCtrl API (get from https://app.cashctrl.com)
CASHCTRL_ORG: "your-org"
CASHCTRL_API_KEY: "your-api-key"
BILLING_START_DATE: "2025-02-01"
CASHCTRL_REVENUE_ACCOUNT_ID: "123"  # Parking revenue account for journal entries
```

**Step 2: Create initializer**

```ruby
# frozen_string_literal: true

# config/initializers/cashctrl.rb
Rails.application.config.cashctrl = {
  org: ENV.fetch('CASHCTRL_ORG', nil),
  api_key: ENV.fetch('CASHCTRL_API_KEY', nil),
  billing_start_date: ENV.fetch('BILLING_START_DATE', nil)&.to_date,
  revenue_account_id: ENV.fetch('CASHCTRL_REVENUE_ACCOUNT_ID', nil)&.to_i
}
```

**Step 3: Commit**

```bash
git add config/initializers/cashctrl.rb
git commit -m "config: add CashCtrl environment configuration"
```

---

### Task 10: Create CashctrlClient Base Class

**Files:**
- Create: `spec/services/cashctrl_client_spec.rb`
- Create: `app/services/cashctrl_client.rb`

**Step 1: Write failing tests**

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CashctrlClient do
  let(:client) { described_class.new }

  describe '#initialize' do
    it 'uses config from Rails' do
      allow(Rails.application.config).to receive(:cashctrl).and_return({
        org: 'test-org',
        api_key: 'test-key'
      })

      client = described_class.new
      expect(client.base_url).to eq('https://test-org.cashctrl.com/api/v1')
    end
  end

  describe '#get' do
    before do
      allow(Rails.application.config).to receive(:cashctrl).and_return({
        org: 'test-org',
        api_key: 'test-key'
      })
    end

    it 'makes authenticated GET request' do
      stub_request(:get, 'https://test-org.cashctrl.com/api/v1/test.json')
        .with(basic_auth: ['test-key', ''])
        .to_return(status: 200, body: '{"success": true}')

      result = client.get('/test.json')
      expect(result).to eq({ 'success' => true })
    end
  end

  describe '#post' do
    before do
      allow(Rails.application.config).to receive(:cashctrl).and_return({
        org: 'test-org',
        api_key: 'test-key'
      })
    end

    it 'makes authenticated POST request' do
      stub_request(:post, 'https://test-org.cashctrl.com/api/v1/test.json')
        .with(basic_auth: ['test-key', ''])
        .to_return(status: 200, body: '{"id": 123}')

      result = client.post('/test.json', { name: 'Test' })
      expect(result).to eq({ 'id' => 123 })
    end
  end
end
```

**Step 2: Add webmock gem**

Add to `Gemfile`:
```ruby
gem 'webmock', group: :test
```

Run: `bundle install`

Add to `spec/rails_helper.rb`:
```ruby
require 'webmock/rspec'
WebMock.disable_net_connect!(allow_localhost: true)
```

**Step 3: Run tests to verify they fail**

Run: `bundle exec rspec spec/services/cashctrl_client_spec.rb`
Expected: FAIL

**Step 4: Implement client**

```ruby
# frozen_string_literal: true

require 'net/http'
require 'json'

class CashctrlClient
  attr_reader :base_url

  def initialize
    config = Rails.application.config.cashctrl
    @org = config[:org]
    @api_key = config[:api_key]
    @base_url = "https://#{@org}.cashctrl.com/api/v1"
  end

  def get(path, params = {})
    uri = URI("#{@base_url}#{path}")
    uri.query = URI.encode_www_form(params) if params.any?

    request = Net::HTTP::Get.new(uri)
    execute(uri, request)
  end

  def post(path, body = {})
    uri = URI("#{@base_url}#{path}")
    request = Net::HTTP::Post.new(uri)
    request.set_form_data(body)
    execute(uri, request)
  end

  private

  def execute(uri, request)
    request.basic_auth(@api_key, '')

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    JSON.parse(response.body)
  end
end
```

**Step 5: Run tests**

Run: `bundle exec rspec spec/services/cashctrl_client_spec.rb`
Expected: PASS

**Step 6: Commit**

```bash
git add Gemfile Gemfile.lock spec/rails_helper.rb spec/services/cashctrl_client_spec.rb app/services/cashctrl_client.rb
git commit -m "feat: add CashctrlClient base class with HTTP methods"
```

---

### Task 11: Add Person API Methods

**Files:**
- Modify: `spec/services/cashctrl_client_spec.rb`
- Modify: `app/services/cashctrl_client.rb`

**Step 1: Add tests**

Add to `spec/services/cashctrl_client_spec.rb`:

```ruby
describe '#find_person_by_email' do
  before do
    allow(Rails.application.config).to receive(:cashctrl).and_return({
      org: 'test-org',
      api_key: 'test-key'
    })
  end

  it 'returns person when found' do
    stub_request(:get, 'https://test-org.cashctrl.com/api/v1/person/list.json')
      .with(query: { query: 'test@example.com' })
      .to_return(status: 200, body: '{"data": [{"id": 123, "email": "test@example.com"}]}')

    result = client.find_person_by_email('test@example.com')
    expect(result['id']).to eq(123)
  end

  it 'returns nil when not found' do
    stub_request(:get, 'https://test-org.cashctrl.com/api/v1/person/list.json')
      .with(query: { query: 'missing@example.com' })
      .to_return(status: 200, body: '{"data": []}')

    result = client.find_person_by_email('missing@example.com')
    expect(result).to be_nil
  end
end

describe '#create_person' do
  before do
    allow(Rails.application.config).to receive(:cashctrl).and_return({
      org: 'test-org',
      api_key: 'test-key'
    })
  end

  it 'creates person and returns id' do
    stub_request(:post, 'https://test-org.cashctrl.com/api/v1/person/create.json')
      .to_return(status: 200, body: '{"success": true, "insertId": 456}')

    result = client.create_person(
      first_name: 'Test',
      last_name: 'User',
      email: 'test@example.com'
    )
    expect(result).to eq(456)
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/services/cashctrl_client_spec.rb`

**Step 3: Implement methods**

Add to `app/services/cashctrl_client.rb`:

```ruby
def find_person_by_email(email)
  result = get('/person/list.json', { query: email })
  result['data']&.first
end

def create_person(first_name:, last_name:, email:)
  result = post('/person/create.json', {
    firstName: first_name,
    lastName: last_name,
    addresses: [{ type: 'MAIN', email: email }].to_json
  })
  result['insertId']
end

def find_or_create_person(user)
  person = find_person_by_email(user.email)
  return person['id'] if person

  create_person(
    first_name: user.first_name,
    last_name: user.last_name,
    email: user.email
  )
end
```

**Step 4: Run tests**

Run: `bundle exec rspec spec/services/cashctrl_client_spec.rb`
Expected: PASS

**Step 5: Commit**

```bash
git add spec/services/cashctrl_client_spec.rb app/services/cashctrl_client.rb
git commit -m "feat: add person lookup and creation to CashctrlClient"
```

---

### Task 12: Add Invoice API Methods

**Files:**
- Modify: `spec/services/cashctrl_client_spec.rb`
- Modify: `app/services/cashctrl_client.rb`

**Step 1: Add tests**

```ruby
describe '#create_invoice' do
  before do
    allow(Rails.application.config).to receive(:cashctrl).and_return({
      org: 'test-org',
      api_key: 'test-key'
    })
  end

  it 'creates invoice with line items' do
    stub_request(:post, 'https://test-org.cashctrl.com/api/v1/order/create.json')
      .to_return(status: 200, body: '{"success": true, "insertId": 789}')

    result = client.create_invoice(
      person_id: 123,
      due_days: 30,
      items: [
        { name: '15.01.2025 | Platz #1 | Ganztag', unit_price: 20.0 }
      ]
    )
    expect(result).to eq(789)
  end
end

describe '#get_invoice' do
  before do
    allow(Rails.application.config).to receive(:cashctrl).and_return({
      org: 'test-org',
      api_key: 'test-key'
    })
  end

  it 'fetches invoice details' do
    stub_request(:get, 'https://test-org.cashctrl.com/api/v1/order/read.json')
      .with(query: { id: '789' })
      .to_return(status: 200, body: '{"id": 789, "statusId": 16}')

    result = client.get_invoice(789)
    expect(result['statusId']).to eq(16)
  end
end

describe '#send_invoice_email' do
  before do
    allow(Rails.application.config).to receive(:cashctrl).and_return({
      org: 'test-org',
      api_key: 'test-key'
    })
  end

  it 'sends invoice via email' do
    stub_request(:post, 'https://test-org.cashctrl.com/api/v1/order/send-email.json')
      .to_return(status: 200, body: '{"success": true}')

    result = client.send_invoice_email(789)
    expect(result['success']).to be true
  end
end

describe '#get_invoice_pdf' do
  before do
    allow(Rails.application.config).to receive(:cashctrl).and_return({
      org: 'test-org',
      api_key: 'test-key'
    })
  end

  it 'returns PDF binary data' do
    pdf_content = '%PDF-1.4 test'
    stub_request(:get, 'https://test-org.cashctrl.com/api/v1/order/document.json')
      .with(query: { id: '789' })
      .to_return(status: 200, body: pdf_content, headers: { 'Content-Type' => 'application/pdf' })

    result = client.get_invoice_pdf(789)
    expect(result).to eq(pdf_content)
  end
end
```

**Step 2: Implement methods**

Add to `app/services/cashctrl_client.rb`:

```ruby
INVOICE_CATEGORY_ID = 1  # Adjust based on CashCtrl setup

def create_invoice(person_id:, due_days:, items:)
  items_json = items.map do |item|
    {
      accountId: 1,  # Revenue account
      name: item[:name],
      unitPrice: item[:unit_price],
      quantity: item[:quantity] || 1
    }
  end

  result = post('/order/create.json', {
    associateId: person_id,
    categoryId: INVOICE_CATEGORY_ID,
    dueDays: due_days,
    items: items_json.to_json
  })
  result['insertId']
end

def get_invoice(invoice_id)
  get('/order/read.json', { id: invoice_id.to_s })
end

def send_invoice_email(invoice_id)
  post('/order/send-email.json', { id: invoice_id })
end

def get_invoice_pdf(invoice_id)
  uri = URI("#{@base_url}/order/document.json?id=#{invoice_id}")
  request = Net::HTTP::Get.new(uri)
  request.basic_auth(@api_key, '')

  Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(request).body
  end
end
```

**Step 3: Run tests**

Run: `bundle exec rspec spec/services/cashctrl_client_spec.rb`
Expected: PASS

**Step 4: Commit**

```bash
git add spec/services/cashctrl_client_spec.rb app/services/cashctrl_client.rb
git commit -m "feat: add invoice methods to CashctrlClient"
```

---

### Task 13: Add Journal Entry and Account Balance Methods

**Files:**
- Modify: `spec/services/cashctrl_client_spec.rb`
- Modify: `app/services/cashctrl_client.rb`

**Step 1: Add tests**

Add to `spec/services/cashctrl_client_spec.rb`:

```ruby
describe '#create_journal_entry' do
  before do
    allow(Rails.application.config).to receive(:cashctrl).and_return({
      org: 'test-org',
      api_key: 'test-key',
      revenue_account_id: 100
    })
  end

  it 'creates journal entry with debit and credit' do
    stub_request(:post, 'https://test-org.cashctrl.com/api/v1/journal/create.json')
      .to_return(status: 200, body: '{"success": true, "insertId": 999}')

    result = client.create_journal_entry(
      debit_account_id: 200,
      credit_account_id: 100,
      amount: 150.50,
      description: 'Parkgebühren Januar 2025'
    )
    expect(result).to eq(999)
  end
end

describe '#get_account_balance' do
  before do
    allow(Rails.application.config).to receive(:cashctrl).and_return({
      org: 'test-org',
      api_key: 'test-key'
    })
  end

  it 'returns account balance' do
    stub_request(:get, 'https://test-org.cashctrl.com/api/v1/account/balance.json')
      .with(query: { id: '200' })
      .to_return(status: 200, body: '{"balance": 350.00}')

    result = client.get_account_balance(200)
    expect(result).to eq(350.00)
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/services/cashctrl_client_spec.rb`

**Step 3: Implement methods**

Add to `app/services/cashctrl_client.rb`:

```ruby
def create_journal_entry(debit_account_id:, credit_account_id:, amount:, description:)
  items = [
    { accountId: debit_account_id, debit: amount },
    { accountId: credit_account_id, credit: amount }
  ]

  result = post('/journal/create.json', {
    dateAdded: Date.today.to_s,
    items: items.to_json,
    notes: description
  })
  result['insertId']
end

def get_account_balance(account_id)
  result = get('/account/balance.json', { id: account_id.to_s })
  result['balance']&.to_f || 0.0
end
```

**Step 4: Run tests**

Run: `bundle exec rspec spec/services/cashctrl_client_spec.rb`
Expected: PASS

**Step 5: Commit**

```bash
git add spec/services/cashctrl_client_spec.rb app/services/cashctrl_client.rb
git commit -m "feat: add journal entry and account balance methods to CashctrlClient"
```

---

## Phase 3: Billing Generation Service

### Task 14: Create InvoiceLineItemBuilder Service

**Files:**
- Create: `spec/services/invoice_line_item_builder_spec.rb`
- Create: `app/services/invoice_line_item_builder.rb`

**Step 1: Write tests**

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvoiceLineItemBuilder do
  let(:user) { User.create!(username: 'test', email: 'test@example.com', first_name: 'Test', last_name: 'User', preferred_language: 'de') }
  let(:parking_spot) { ParkingSpot.create!(number: 42) }
  let(:vehicle) { Vehicle.create!(user: user, license_plate_number: 'ZH 123', make: 'VW', model: 'Golf') }

  describe '#build_description' do
    it 'formats German description for full day car' do
      reservation = Reservation.create!(
        user: user,
        vehicle: vehicle,
        parking_spot: parking_spot,
        date: Date.new(2025, 1, 15),
        half_day: false
      )

      builder = described_class.new(reservation, 'de')
      expect(builder.build_description).to eq('15.01.2025 | Platz #42 | Ganztag | Auto')
    end

    it 'formats English description' do
      reservation = Reservation.create!(
        user: user,
        vehicle: vehicle,
        parking_spot: parking_spot,
        date: Date.new(2025, 1, 15),
        half_day: false
      )

      builder = described_class.new(reservation, 'en')
      expect(builder.build_description).to eq('15.01.2025 | Spot #42 | Full day | Car')
    end

    it 'includes cancelled suffix for cancelled reservations' do
      reservation = Reservation.create!(
        user: user,
        vehicle: vehicle,
        parking_spot: parking_spot,
        date: Date.new(2025, 1, 15),
        half_day: false,
        cancelled: true,
        cancelled_at: Time.now
      )

      builder = described_class.new(reservation, 'de')
      expect(builder.build_description).to include('(Storniert)')
    end
  end
end
```

**Step 2: Implement service**

```ruby
# frozen_string_literal: true

class InvoiceLineItemBuilder
  TRANSLATIONS = {
    'de' => { spot: 'Platz', full_day: 'Ganztag', half_day_am: 'Vormittag', half_day_pm: 'Nachmittag', car: 'Auto', motorcycle: 'Motorrad', cancelled: 'Storniert' },
    'en' => { spot: 'Spot', full_day: 'Full day', half_day_am: 'Morning', half_day_pm: 'Afternoon', car: 'Car', motorcycle: 'Motorcycle', cancelled: 'Cancelled' },
    'fr' => { spot: 'Place', full_day: 'Journée', half_day_am: 'Matin', half_day_pm: 'Après-midi', car: 'Voiture', motorcycle: 'Moto', cancelled: 'Annulé' },
    'it' => { spot: 'Posto', full_day: 'Giornata', half_day_am: 'Mattina', half_day_pm: 'Pomeriggio', car: 'Auto', motorcycle: 'Moto', cancelled: 'Annullato' }
  }.freeze

  def initialize(reservation, language = 'de')
    @reservation = reservation
    @language = language
    @t = TRANSLATIONS[language] || TRANSLATIONS['de']
  end

  def build_description
    parts = [
      @reservation.date.strftime('%d.%m.%Y'),
      "#{@t[:spot]} ##{@reservation.parking_spot.number}",
      time_slot_description,
      vehicle_type_description
    ]

    desc = parts.join(' | ')
    desc += " (#{@t[:cancelled]})" if @reservation.cancelled?
    desc
  end

  def unit_price
    @reservation.cancelled? ? 0.0 : @reservation.price
  end

  private

  def time_slot_description
    if @reservation.half_day?
      @reservation.am? ? @t[:half_day_am] : @t[:half_day_pm]
    else
      @t[:full_day]
    end
  end

  def vehicle_type_description
    @reservation.vehicle.motorcycle? ? @t[:motorcycle] : @t[:car]
  end
end
```

**Step 3: Run tests**

Run: `bundle exec rspec spec/services/invoice_line_item_builder_spec.rb`
Expected: PASS

**Step 4: Commit**

```bash
git add spec/services/invoice_line_item_builder_spec.rb app/services/invoice_line_item_builder.rb
git commit -m "feat: add InvoiceLineItemBuilder for localized descriptions"
```

---

### Task 15: Create BillingRunner Service

**Files:**
- Create: `spec/services/billing_runner_spec.rb`
- Create: `app/services/billing_runner.rb`

**Step 1: Write tests** (comprehensive test file)

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BillingRunner do
  let(:standard_user) { User.create!(username: 'standard', email: 'standard@example.com', first_name: 'Standard', last_name: 'User', billing_type: :standard) }
  let(:prepaid_user) { User.create!(username: 'prepaid', email: 'prepaid@example.com', first_name: 'Prepaid', last_name: 'User', billing_type: :prepaid, cashctrl_private_account_id: 200, prepaid_threshold: 100, prepaid_topup_amount: 500) }
  let(:exempt_user) { User.create!(username: 'exempt', email: 'exempt@example.com', first_name: 'Exempt', last_name: 'User', billing_type: :exempt) }
  let(:parking_spot) { ParkingSpot.create!(number: 1) }
  let(:standard_vehicle) { Vehicle.create!(user: standard_user, license_plate_number: 'ZH 123', make: 'VW', model: 'Golf') }
  let(:prepaid_vehicle) { Vehicle.create!(user: prepaid_user, license_plate_number: 'ZH 456', make: 'BMW', model: '3') }
  let(:exempt_vehicle) { Vehicle.create!(user: exempt_user, license_plate_number: 'ZH 789', make: 'Audi', model: 'A4') }
  let(:cashctrl_client) { instance_double(CashctrlClient) }

  before do
    allow(CashctrlClient).to receive(:new).and_return(cashctrl_client)
    allow(Rails.application.config).to receive(:cashctrl).and_return({
      billing_start_date: Date.new(2025, 1, 1),
      revenue_account_id: 100
    })
  end

  let(:period_start) { Date.new(2025, 1, 1) }
  let(:period_end) { Date.new(2025, 1, 31) }

  describe 'standard users' do
    before do
      Reservation.create!(user: standard_user, vehicle: standard_vehicle, parking_spot: parking_spot, date: Date.new(2025, 1, 15), half_day: false)
      allow(cashctrl_client).to receive(:find_or_create_person).and_return(123)
      allow(cashctrl_client).to receive(:create_invoice).and_return(456)
    end

    it 'creates invoice for standard user' do
      runner = described_class.new(period_start, period_end)
      result = runner.run

      expect(result[:standard][:created]).to eq(1)
      expect(Invoice.count).to eq(1)
    end
  end

  describe 'prepaid users' do
    before do
      Reservation.create!(user: prepaid_user, vehicle: prepaid_vehicle, parking_spot: parking_spot, date: Date.new(2025, 1, 15), half_day: false)
      allow(cashctrl_client).to receive(:find_or_create_person).and_return(789)
      allow(cashctrl_client).to receive(:create_journal_entry).and_return(999)
      allow(cashctrl_client).to receive(:get_account_balance).and_return(350.0)  # Above threshold
    end

    it 'creates journal entry for prepaid user' do
      runner = described_class.new(period_start, period_end)
      result = runner.run

      expect(result[:prepaid][:journal_entries_created]).to eq(1)
      expect(JournalEntry.count).to eq(1)
    end

    it 'generates top-up invoice when balance below threshold' do
      allow(cashctrl_client).to receive(:get_account_balance).and_return(50.0)  # Below threshold
      allow(cashctrl_client).to receive(:create_invoice).and_return(888)

      runner = described_class.new(period_start, period_end)
      result = runner.run

      expect(result[:prepaid][:topup_invoices_created]).to eq(1)
    end
  end

  describe 'exempt users' do
    before do
      Reservation.create!(user: exempt_user, vehicle: exempt_vehicle, parking_spot: parking_spot, date: Date.new(2025, 1, 15), half_day: false)
    end

    it 'skips exempt users' do
      runner = described_class.new(period_start, period_end)
      result = runner.run

      expect(result[:exempt][:skipped]).to eq(1)
      expect(Invoice.count).to eq(0)
      expect(JournalEntry.count).to eq(0)
    end
  end
end
```

**Step 2: Implement service**

```ruby
# frozen_string_literal: true

class BillingRunner
  def initialize(period_start, period_end)
    @period_start = period_start
    @period_end = period_end
    @client = CashctrlClient.new
    @results = {
      standard: { created: 0, skipped: 0 },
      prepaid: { journal_entries_created: 0, topup_invoices_created: 0, skipped: 0 },
      exempt: { skipped: 0 },
      errors: []
    }
  end

  def run
    validate_period!

    process_standard_users
    process_prepaid_users
    process_exempt_users

    @results
  end

  def preview
    {
      standard: preview_standard_users,
      prepaid: preview_prepaid_users,
      exempt: preview_exempt_users
    }
  end

  private

  def validate_period!
    billing_start = Rails.application.config.cashctrl[:billing_start_date]
    raise 'Period is before billing start date' if billing_start && @period_start < billing_start
    raise 'Cannot bill current or future months' if @period_end >= Date.today.beginning_of_month
  end

  def users_with_reservations
    User.joins(:reservations)
        .where(reservations: { date: @period_start..@period_end })
        .distinct
  end

  def user_reservations(user)
    user.reservations.where(date: @period_start..@period_end)
  end

  def user_total(user)
    user_reservations(user).where(cancelled: false).sum(:price)
  end

  # === Standard Users ===

  def process_standard_users
    users_with_reservations.standard_billing.find_each do |user|
      process_standard_user(user)
    rescue StandardError => e
      @results[:errors] << { user_id: user.id, type: :standard, error: e.message }
    end
  end

  def process_standard_user(user)
    if Invoice.exists?(user: user, period_start: @period_start) || user_total(user) <= 0
      @results[:standard][:skipped] += 1
      return
    end

    person_id = ensure_cashctrl_person(user)
    reservations = user_reservations(user)
    language = user.preferred_language || 'de'

    items = build_line_items(reservations, language)
    total = items.sum { |i| i[:unit_price] }

    cashctrl_invoice_id = @client.create_invoice(
      person_id: person_id,
      due_days: 30,
      items: items.map { |i| { name: i[:description], unit_price: i[:unit_price] } }
    )

    invoice = Invoice.create!(
      user: user,
      cashctrl_person_id: person_id,
      cashctrl_invoice_id: cashctrl_invoice_id,
      period_start: @period_start,
      period_end: @period_end,
      total_amount: total,
      status: :draft
    )

    create_local_line_items(invoice, items)
    @results[:standard][:created] += 1
  end

  def preview_standard_users
    users_with_reservations.standard_billing
      .where.not(id: Invoice.where(period_start: @period_start).pluck(:user_id))
      .map { |u| { user: u, total: user_total(u), reservations: user_reservations(u).count } }
      .select { |p| p[:total] > 0 }
  end

  # === Prepaid Users ===

  def process_prepaid_users
    users_with_reservations.prepaid_billing.find_each do |user|
      process_prepaid_user(user)
    rescue StandardError => e
      @results[:errors] << { user_id: user.id, type: :prepaid, error: e.message }
    end
  end

  def process_prepaid_user(user)
    if JournalEntry.exists?(user: user, period_start: @period_start)
      @results[:prepaid][:skipped] += 1
      return
    end

    total = user_total(user)
    return if total <= 0

    # Create journal entry
    revenue_account_id = Rails.application.config.cashctrl[:revenue_account_id]
    description = journal_entry_description(user.preferred_language || 'de')

    cashctrl_journal_id = @client.create_journal_entry(
      debit_account_id: user.cashctrl_private_account_id,
      credit_account_id: revenue_account_id,
      amount: total,
      description: description
    )

    JournalEntry.create!(
      user: user,
      cashctrl_journal_id: cashctrl_journal_id,
      period_start: @period_start,
      period_end: @period_end,
      total_amount: total,
      reservation_count: user_reservations(user).count
    )

    @results[:prepaid][:journal_entries_created] += 1

    # Check if top-up needed
    check_and_create_topup_invoice(user)
  end

  def check_and_create_topup_invoice(user)
    return unless user.prepaid_threshold && user.prepaid_topup_amount

    balance = @client.get_account_balance(user.cashctrl_private_account_id)
    return if balance >= user.prepaid_threshold

    person_id = ensure_cashctrl_person(user)
    topup_description = topup_line_item_description(user.preferred_language || 'de')

    cashctrl_invoice_id = @client.create_invoice(
      person_id: person_id,
      due_days: 30,
      items: [{ name: topup_description, unit_price: user.prepaid_topup_amount }]
    )

    Invoice.create!(
      user: user,
      cashctrl_person_id: person_id,
      cashctrl_invoice_id: cashctrl_invoice_id,
      period_start: @period_start,
      period_end: @period_end,
      total_amount: user.prepaid_topup_amount,
      status: :draft
    )

    @results[:prepaid][:topup_invoices_created] += 1
  end

  def preview_prepaid_users
    users_with_reservations.prepaid_billing
      .where.not(id: JournalEntry.where(period_start: @period_start).pluck(:user_id))
      .map { |u| { user: u, total: user_total(u), reservations: user_reservations(u).count } }
      .select { |p| p[:total] > 0 }
  end

  # === Exempt Users ===

  def process_exempt_users
    count = users_with_reservations.exempt_billing.count
    @results[:exempt][:skipped] = count
  end

  def preview_exempt_users
    users_with_reservations.exempt_billing
      .map { |u| { user: u, total: user_total(u), reservations: user_reservations(u).count } }
  end

  # === Helpers ===

  def ensure_cashctrl_person(user)
    return user.cashctrl_person_id if user.cashctrl_person_id

    person_id = @client.find_or_create_person(user)
    user.update!(cashctrl_person_id: person_id)
    person_id
  end

  def build_line_items(reservations, language)
    reservations.map do |reservation|
      builder = InvoiceLineItemBuilder.new(reservation, language)
      { reservation: reservation, description: builder.build_description, unit_price: builder.unit_price }
    end
  end

  def create_local_line_items(invoice, items)
    items.each do |item|
      InvoiceLineItem.create!(
        invoice: invoice,
        reservation: item[:reservation],
        description: item[:description],
        unit_price: item[:unit_price]
      )
    end
  end

  JOURNAL_DESCRIPTIONS = {
    'de' => 'Parkgebühren %B %Y',
    'en' => 'Parking fees %B %Y',
    'fr' => 'Frais de parking %B %Y',
    'it' => 'Spese parcheggio %B %Y'
  }.freeze

  TOPUP_DESCRIPTIONS = {
    'de' => 'Aufladung Parkkonto',
    'en' => 'Parking account top-up',
    'fr' => 'Rechargement compte parking',
    'it' => 'Ricarica conto parcheggio'
  }.freeze

  def journal_entry_description(language)
    template = JOURNAL_DESCRIPTIONS[language] || JOURNAL_DESCRIPTIONS['de']
    @period_start.strftime(template)
  end

  def topup_line_item_description(language)
    TOPUP_DESCRIPTIONS[language] || TOPUP_DESCRIPTIONS['de']
  end
end
```

**Step 3: Run tests**

Run: `bundle exec rspec spec/services/billing_runner_spec.rb`
Expected: PASS

**Step 4: Commit**

```bash
git add spec/services/billing_runner_spec.rb app/services/billing_runner.rb
git commit -m "feat: add BillingRunner service for all billing types"
```

---

## Phase 4: Admin Interface

### Task 16: Create Admin BillingController

**Files:**
- Create: `app/controllers/admin/billing_controller.rb`
- Create: `app/controllers/admin/invoices_controller.rb`
- Create: `app/controllers/admin/journal_entries_controller.rb`

**Step 1: Create billing controller (dashboard and run)**

```ruby
# frozen_string_literal: true

module Admin
  class BillingController < AuthorizableController
    before_action :require_admin!

    def index
      @stats = {
        total_open: Invoice.open.sum(:total_amount),
        invoices_by_status: Invoice.group(:status).count,
        journal_entries_this_month: JournalEntry.where(period_start: Date.today.beginning_of_month).count
      }
    end

    def run
      @available_months = available_months_for_billing
    end

    def preview
      period = parse_period(params[:period])
      runner = BillingRunner.new(period[:start], period[:end])
      @preview = runner.preview
      @period = period
    end

    def execute
      period = parse_period(params[:period])
      runner = BillingRunner.new(period[:start], period[:end])
      @result = runner.run

      redirect_to admin_billing_path, notice: billing_notice(@result)
    end

    private

    def require_admin!
      redirect_to root_path unless current_user&.admin?
    end

    def available_months_for_billing
      billing_start = Rails.application.config.cashctrl[:billing_start_date] || 6.months.ago.to_date
      start_month = billing_start.beginning_of_month
      end_month = 1.month.ago.beginning_of_month

      months = []
      current = end_month
      while current >= start_month
        months << { start: current, end: current.end_of_month, label: current.strftime('%B %Y') }
        current -= 1.month
      end
      months
    end

    def parse_period(period_string)
      date = Date.parse(period_string)
      { start: date.beginning_of_month, end: date.end_of_month }
    end

    def billing_notice(result)
      parts = []
      parts << "Standard: #{result[:standard][:created]} invoices" if result[:standard][:created] > 0
      parts << "Prepaid: #{result[:prepaid][:journal_entries_created]} journal entries" if result[:prepaid][:journal_entries_created] > 0
      parts << "#{result[:prepaid][:topup_invoices_created]} top-up invoices" if result[:prepaid][:topup_invoices_created] > 0
      parts << "Exempt: #{result[:exempt][:skipped]} skipped" if result[:exempt][:skipped] > 0
      parts.join(', ')
    end
  end
end
```

**Step 2: Create invoices controller**

```ruby
# frozen_string_literal: true

module Admin
  class InvoicesController < AuthorizableController
    before_action :require_admin!
    before_action :set_invoice, only: [:show, :send_email, :download_pdf, :refresh_status]

    def index
      @invoices = Invoice.includes(:user)
                         .order(created_at: :desc)
                         .page(params[:page])
                         .per(25)
    end

    def send_email
      client = CashctrlClient.new
      client.send_invoice_email(@invoice.cashctrl_invoice_id)
      @invoice.update!(sent_at: Time.current, status: :sent)

      redirect_to admin_invoices_path, notice: 'Invoice sent successfully'
    end

    def download_pdf
      client = CashctrlClient.new
      pdf_data = client.get_invoice_pdf(@invoice.cashctrl_invoice_id)

      send_data pdf_data,
                filename: "invoice-#{@invoice.id}.pdf",
                type: 'application/pdf',
                disposition: 'attachment'
    end

    def refresh_status
      sync_invoice_status(@invoice)
      redirect_to admin_invoices_path, notice: 'Status refreshed'
    end

    def refresh_all
      Invoice.open.find_each { |invoice| sync_invoice_status(invoice) }
      redirect_to admin_invoices_path, notice: 'All statuses refreshed'
    end

    private

    def set_invoice
      @invoice = Invoice.find(params[:id])
    end

    def require_admin!
      redirect_to root_path unless current_user&.admin?
    end

    def sync_invoice_status(invoice)
      return unless invoice.cashctrl_invoice_id

      client = CashctrlClient.new
      data = client.get_invoice(invoice.cashctrl_invoice_id)

      new_status = case data['statusId']
                   when 7 then :draft
                   when 16 then :sent
                   when 17 then :paid
                   else invoice.status
                   end

      invoice.update!(
        status: new_status,
        cashctrl_status: data['statusId'].to_s,
        paid_at: new_status == :paid ? Time.current : invoice.paid_at
      )
    end
  end
end
```

**Step 3: Create journal entries controller**

```ruby
# frozen_string_literal: true

module Admin
  class JournalEntriesController < AuthorizableController
    before_action :require_admin!

    def index
      @journal_entries = JournalEntry.includes(:user)
                                      .order(created_at: :desc)
                                      .page(params[:page])
                                      .per(25)
    end

    private

    def require_admin!
      redirect_to root_path unless current_user&.admin?
    end
  end
end
```

**Step 4: Add routes**

Add to `config/routes.rb`:

```ruby
namespace :admin do
  resource :billing, only: [:show], controller: 'billing' do
    get :run
    get :preview
    post :execute
  end

  resources :invoices, only: [:index, :show] do
    collection do
      post :refresh_all
    end
    member do
      post :send_email
      get :download_pdf
      post :refresh_status
    end
  end

  resources :journal_entries, only: [:index]
end
```

**Step 5: Commit**

```bash
git add app/controllers/admin/ config/routes.rb
git commit -m "feat: add Admin billing, invoices, and journal entries controllers"
```

---

### Task 17: Create Admin Billing Views

**Files:**
- Create: `app/views/admin/billing/show.html.erb`
- Create: `app/views/admin/billing/run.html.erb`
- Create: `app/views/admin/billing/preview.html.erb`
- Create: `app/views/admin/invoices/index.html.erb`
- Create: `app/views/admin/journal_entries/index.html.erb`

**Step 1: Create billing dashboard view**

```erb
<%# app/views/admin/billing/show.html.erb %>
<h1>Billing Dashboard</h1>

<div class="stats">
  <p>Open Invoice Amount: <%= number_to_currency(@stats[:total_open], unit: 'CHF ') %></p>
  <p>
    <% @stats[:invoices_by_status].each do |status, count| %>
      <%= status.capitalize %>: <%= count %> |
    <% end %>
  </p>
  <p>Journal Entries this month: <%= @stats[:journal_entries_this_month] %></p>
</div>

<div class="actions">
  <%= link_to 'Run Billing', run_admin_billing_path, class: 'btn btn-primary' %>
  <%= link_to 'View Invoices', admin_invoices_path, class: 'btn' %>
  <%= link_to 'View Journal Entries', admin_journal_entries_path, class: 'btn' %>
  <%= button_to 'Refresh All Statuses', refresh_all_admin_invoices_path, method: :post, class: 'btn' %>
</div>
```

**Step 2: Create billing run view**

```erb
<%# app/views/admin/billing/run.html.erb %>
<h1>Run Billing</h1>

<%= form_tag preview_admin_billing_path, method: :get do %>
  <div>
    <label>Select Month:</label>
    <%= select_tag :period, options_for_select(@available_months.map { |m| [m[:label], m[:start].to_s] }) %>
  </div>
  <div>
    <%= submit_tag 'Preview', class: 'btn' %>
  </div>
<% end %>

<p><%= link_to 'Back to Dashboard', admin_billing_path %></p>
```

**Step 3: Create billing preview view**

```erb
<%# app/views/admin/billing/preview.html.erb %>
<h1>Billing Preview - <%= @period[:start].strftime('%B %Y') %></h1>

<h2>Standard Users (Invoices)</h2>
<% if @preview[:standard].any? %>
  <table>
    <thead><tr><th>User</th><th>Reservations</th><th>Total</th></tr></thead>
    <tbody>
      <% @preview[:standard].each do |item| %>
        <tr>
          <td><%= item[:user].email %></td>
          <td><%= item[:reservations] %></td>
          <td><%= number_to_currency(item[:total], unit: 'CHF ') %></td>
        </tr>
      <% end %>
    </tbody>
  </table>
<% else %>
  <p>No standard users to invoice.</p>
<% end %>

<h2>Prepaid Users (Journal Entries)</h2>
<% if @preview[:prepaid].any? %>
  <table>
    <thead><tr><th>User</th><th>Reservations</th><th>Total</th></tr></thead>
    <tbody>
      <% @preview[:prepaid].each do |item| %>
        <tr>
          <td><%= item[:user].email %></td>
          <td><%= item[:reservations] %></td>
          <td><%= number_to_currency(item[:total], unit: 'CHF ') %></td>
        </tr>
      <% end %>
    </tbody>
  </table>
<% else %>
  <p>No prepaid users to process.</p>
<% end %>

<h2>Exempt Users (Skipped)</h2>
<% if @preview[:exempt].any? %>
  <p><%= @preview[:exempt].count %> exempt users will be skipped.</p>
<% else %>
  <p>No exempt users.</p>
<% end %>

<%= button_to 'Run Billing', execute_admin_billing_path(period: @period[:start]), method: :post, class: 'btn btn-primary' %>
<p><%= link_to 'Back', run_admin_billing_path %></p>
```

**Step 4: Create invoices index view**

```erb
<%# app/views/admin/invoices/index.html.erb %>
<h1>Invoices</h1>

<p><%= link_to 'Back to Billing', admin_billing_path %></p>

<table>
  <thead>
    <tr>
      <th>User</th>
      <th>Billing Type</th>
      <th>Period</th>
      <th>Amount</th>
      <th>Status</th>
      <th>Sent</th>
      <th>Actions</th>
    </tr>
  </thead>
  <tbody>
    <% @invoices.each do |invoice| %>
      <tr>
        <td><%= invoice.user.email %></td>
        <td><%= invoice.user.billing_type %></td>
        <td><%= invoice.period_start.strftime('%B %Y') %></td>
        <td><%= number_to_currency(invoice.total_amount, unit: 'CHF ') %></td>
        <td><%= invoice.status %></td>
        <td><%= invoice.sent_at&.strftime('%d.%m.%Y') || '-' %></td>
        <td>
          <% unless invoice.sent? || invoice.paid? %>
            <%= button_to 'Send', send_email_admin_invoice_path(invoice), method: :post, class: 'btn-small' %>
          <% end %>
          <%= link_to 'PDF', download_pdf_admin_invoice_path(invoice), class: 'btn-small' %>
          <%= button_to 'Refresh', refresh_status_admin_invoice_path(invoice), method: :post, class: 'btn-small' %>
        </td>
      </tr>
    <% end %>
  </tbody>
</table>

<%= paginate @invoices %>
```

**Step 5: Create journal entries index view**

```erb
<%# app/views/admin/journal_entries/index.html.erb %>
<h1>Journal Entries (Prepaid Users)</h1>

<p><%= link_to 'Back to Billing', admin_billing_path %></p>

<table>
  <thead>
    <tr>
      <th>User</th>
      <th>Period</th>
      <th>Amount</th>
      <th>Reservations</th>
      <th>Created</th>
    </tr>
  </thead>
  <tbody>
    <% @journal_entries.each do |entry| %>
      <tr>
        <td><%= entry.user.email %></td>
        <td><%= entry.period_start.strftime('%B %Y') %></td>
        <td><%= number_to_currency(entry.total_amount, unit: 'CHF ') %></td>
        <td><%= entry.reservation_count %></td>
        <td><%= entry.created_at.strftime('%d.%m.%Y') %></td>
      </tr>
    <% end %>
  </tbody>
</table>

<%= paginate @journal_entries %>
```

**Step 6: Commit**

```bash
git add app/views/admin/
git commit -m "feat: add admin billing, invoices, and journal entries views"
```

---

### Task 18: Create Billing Policies

**Files:**
- Create: `app/policies/invoice_policy.rb`
- Create: `app/policies/journal_entry_policy.rb`

**Step 1: Create invoice policy**

```ruby
# frozen_string_literal: true

class InvoicePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      user.admin? ? scope.all : scope.none
    end
  end

  def index?
    user.admin?
  end

  def show?
    user.admin?
  end

  def create?
    user.admin?
  end

  def send_email?
    user.admin?
  end

  def download_pdf?
    user.admin? || user.id == record.user_id
  end
end
```

**Step 2: Create journal entry policy**

```ruby
# frozen_string_literal: true

class JournalEntryPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      user.admin? ? scope.all : scope.none
    end
  end

  def index?
    user.admin?
  end

  def show?
    user.admin?
  end
end
```

**Step 3: Commit**

```bash
git add app/policies/invoice_policy.rb app/policies/journal_entry_policy.rb
git commit -m "feat: add Invoice and JournalEntry policies for authorization"
```

---

## Phase 5: Background Jobs

### Task 19: Create Invoice Status Sync Job

**Files:**
- Create: `app/jobs/sync_invoice_statuses_job.rb`
- Create: `spec/jobs/sync_invoice_statuses_job_spec.rb`

**Step 1: Write test**

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncInvoiceStatusesJob, type: :job do
  let(:user) { User.create!(username: 'test', email: 'test@example.com', first_name: 'Test', last_name: 'User') }
  let(:client) { instance_double(CashctrlClient) }

  before do
    allow(CashctrlClient).to receive(:new).and_return(client)
  end

  it 'syncs open invoice statuses' do
    invoice = Invoice.create!(
      user: user,
      cashctrl_person_id: 123,
      cashctrl_invoice_id: 456,
      period_start: Date.new(2025, 1, 1),
      period_end: Date.new(2025, 1, 31),
      status: :sent
    )

    allow(client).to receive(:get_invoice).with(456).and_return({ 'statusId' => 17 })

    described_class.perform_now

    invoice.reload
    expect(invoice.status).to eq('paid')
  end
end
```

**Step 2: Create job**

```ruby
# frozen_string_literal: true

class SyncInvoiceStatusesJob < ApplicationJob
  queue_as :default

  STATUS_MAP = {
    7 => :draft,
    16 => :sent,
    17 => :paid
  }.freeze

  def perform
    client = CashctrlClient.new

    Invoice.open.where.not(cashctrl_invoice_id: nil).find_each do |invoice|
      sync_invoice(client, invoice)
    rescue StandardError => e
      Rails.logger.error "Failed to sync invoice #{invoice.id}: #{e.message}"
    end
  end

  private

  def sync_invoice(client, invoice)
    data = client.get_invoice(invoice.cashctrl_invoice_id)
    new_status = STATUS_MAP[data['statusId']] || invoice.status

    updates = { cashctrl_status: data['statusId'].to_s }
    updates[:status] = new_status if STATUS_MAP.key?(data['statusId'])
    updates[:paid_at] = Time.current if new_status == :paid && invoice.paid_at.nil?

    invoice.update!(updates)
  end
end
```

**Step 3: Run tests**

Run: `bundle exec rspec spec/jobs/sync_invoice_statuses_job_spec.rb`
Expected: PASS

**Step 4: Commit**

```bash
git add spec/jobs/sync_invoice_statuses_job_spec.rb app/jobs/sync_invoice_statuses_job.rb
git commit -m "feat: add SyncInvoiceStatusesJob for daily status sync"
```

---

### Task 20: Add Rake Task for Scheduler

**Files:**
- Create: `lib/tasks/invoices.rake`

**Step 1: Create rake task**

```ruby
# frozen_string_literal: true

namespace :invoices do
  desc 'Sync invoice statuses from CashCtrl'
  task sync_statuses: :environment do
    SyncInvoiceStatusesJob.perform_now
  end
end
```

**Step 2: Commit**

```bash
git add lib/tasks/invoices.rake
git commit -m "feat: add invoices:sync_statuses rake task for Heroku Scheduler"
```

---

## Phase 6: Final Integration

### Task 21: Add Navigation Link

**Files:**
- Modify: `app/views/layouts/_navigation.html.erb` (or equivalent)

Add admin nav link:
```erb
<% if current_user&.admin? %>
  <%= link_to 'Billing', admin_billing_path %>
<% end %>
```

**Commit:**

```bash
git add app/views/layouts/
git commit -m "feat: add Billing link to admin navigation"
```

---

### Task 22: Run Full Test Suite

**Step 1: Run all tests**

Run: `bundle exec rspec`
Expected: All new tests PASS

**Step 2: Final commit**

```bash
git add -A
git commit -m "feat: complete CashCtrl billing integration with all billing types"
```

---

## Summary

| Phase | Tasks | Description |
|-------|-------|-------------|
| 1 | 1-8 | Database migrations and models (users billing fields, invoices, line items, journal entries) |
| 2 | 9-13 | CashCtrl API client (base, person, invoice, journal entry, account balance) |
| 3 | 14-15 | Billing services (line item builder, billing runner for all types) |
| 4 | 16-18 | Admin interface (controllers, views, policies) |
| 5 | 19-20 | Background jobs (status sync, rake task) |
| 6 | 21-22 | Final integration (navigation, full test suite) |

**Total Tasks:** 22
**Billing Types Supported:**
- Standard: Monthly invoices with line items per reservation
- Prepaid: Journal entries against private account + top-up invoices when balance low
- Exempt: No billing action, reservations tracked for statistics

**Implementation Approach:** TDD with frequent commits
