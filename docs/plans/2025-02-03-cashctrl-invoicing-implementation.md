# CashCtrl Invoicing Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a monthly invoicing system that generates invoices in CashCtrl for parking reservations, with local tracking and admin interface.

**Architecture:** Rails service objects for CashCtrl API integration, ActiveRecord models for local invoice storage, Turbo-powered admin views for invoice management. TDD with RSpec.

**Tech Stack:** Rails 7.1, PostgreSQL, CashCtrl REST API, Turbo/Stimulus, RSpec

---

## Phase 1: Database & Models

### Task 1: Create Invoice Migration

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

### Task 2: Create InvoiceLineItem Migration

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

### Task 3: Create Invoice Model with Tests

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

### Task 4: Create InvoiceLineItem Model with Tests

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

### Task 5: Add User Association to Invoice

**Files:**
- Modify: `app/models/user.rb`

**Step 1: Add association**

Add to `app/models/user.rb`:

```ruby
has_many :invoices, dependent: :destroy
```

**Step 2: Commit**

```bash
git add app/models/user.rb
git commit -m "feat: add invoices association to User"
```

---

## Phase 2: CashCtrl API Client

### Task 6: Add Environment Configuration

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
```

**Step 2: Create initializer**

```ruby
# frozen_string_literal: true

# config/initializers/cashctrl.rb
Rails.application.config.cashctrl = {
  org: ENV.fetch('CASHCTRL_ORG', nil),
  api_key: ENV.fetch('CASHCTRL_API_KEY', nil),
  billing_start_date: ENV.fetch('BILLING_START_DATE', nil)&.to_date
}
```

**Step 3: Commit**

```bash
git add config/initializers/cashctrl.rb
git commit -m "config: add CashCtrl environment configuration"
```

---

### Task 7: Create CashctrlClient Base Class

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

### Task 8: Add Person API Methods

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

### Task 9: Add Invoice API Methods

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

## Phase 3: Invoice Generation Service

### Task 10: Create InvoiceLineItemBuilder Service

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

### Task 11: Create InvoiceGenerator Service

**Files:**
- Create: `spec/services/invoice_generator_spec.rb`
- Create: `app/services/invoice_generator.rb`

**Step 1: Write tests** (comprehensive test file)

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvoiceGenerator do
  let(:user) { User.create!(username: 'test', email: 'test@example.com', first_name: 'Test', last_name: 'User') }
  let(:parking_spot) { ParkingSpot.create!(number: 1) }
  let(:vehicle) { Vehicle.create!(user: user, license_plate_number: 'ZH 123', make: 'VW', model: 'Golf') }
  let(:cashctrl_client) { instance_double(CashctrlClient) }

  before do
    allow(CashctrlClient).to receive(:new).and_return(cashctrl_client)
    allow(Rails.application.config).to receive(:cashctrl).and_return({
      billing_start_date: Date.new(2025, 1, 1)
    })
  end

  describe '#generate_for_period' do
    let(:period_start) { Date.new(2025, 1, 1) }
    let(:period_end) { Date.new(2025, 1, 31) }

    context 'with eligible user' do
      before do
        # Create a reservation in January with price > 0
        Reservation.create!(
          user: user,
          vehicle: vehicle,
          parking_spot: parking_spot,
          date: Date.new(2025, 1, 15),  # Wednesday
          half_day: false
        )

        allow(cashctrl_client).to receive(:find_or_create_person).and_return(123)
        allow(cashctrl_client).to receive(:create_invoice).and_return(456)
      end

      it 'creates invoice for user with reservations' do
        generator = described_class.new(period_start, period_end)
        result = generator.generate

        expect(result[:created]).to eq(1)
        expect(Invoice.count).to eq(1)
      end

      it 'stores cashctrl references' do
        generator = described_class.new(period_start, period_end)
        generator.generate

        invoice = Invoice.last
        expect(invoice.cashctrl_person_id).to eq(123)
        expect(invoice.cashctrl_invoice_id).to eq(456)
      end

      it 'creates line items' do
        generator = described_class.new(period_start, period_end)
        generator.generate

        expect(InvoiceLineItem.count).to eq(1)
      end
    end

    context 'with already invoiced user' do
      before do
        Reservation.create!(
          user: user,
          vehicle: vehicle,
          parking_spot: parking_spot,
          date: Date.new(2025, 1, 15),
          half_day: false
        )
        Invoice.create!(
          user: user,
          cashctrl_person_id: 123,
          period_start: period_start,
          period_end: period_end
        )
      end

      it 'skips already invoiced users' do
        generator = described_class.new(period_start, period_end)
        result = generator.generate

        expect(result[:skipped]).to eq(1)
        expect(result[:created]).to eq(0)
      end
    end

    context 'with zero-amount user' do
      before do
        # Weekend reservation = free
        Reservation.create!(
          user: user,
          vehicle: vehicle,
          parking_spot: parking_spot,
          date: Date.new(2025, 1, 18),  # Saturday
          half_day: false
        )
      end

      it 'skips users with only free reservations' do
        generator = described_class.new(period_start, period_end)
        result = generator.generate

        expect(result[:created]).to eq(0)
      end
    end
  end
end
```

**Step 2: Implement service**

```ruby
# frozen_string_literal: true

class InvoiceGenerator
  def initialize(period_start, period_end)
    @period_start = period_start
    @period_end = period_end
    @client = CashctrlClient.new
    @results = { created: 0, skipped: 0, errors: [] }
  end

  def generate
    validate_period!

    eligible_users.each do |user|
      process_user(user)
    rescue StandardError => e
      @results[:errors] << { user_id: user.id, error: e.message }
    end

    @results
  end

  def preview
    eligible_users.map do |user|
      reservations = user_reservations(user)
      {
        user: user,
        reservation_count: reservations.count,
        total_amount: reservations.sum(&:price)
      }
    end
  end

  private

  def validate_period!
    billing_start = Rails.application.config.cashctrl[:billing_start_date]
    raise 'Period is before billing start date' if billing_start && @period_start < billing_start
    raise 'Cannot invoice current or future months' if @period_end >= Date.today.beginning_of_month
  end

  def eligible_users
    User.joins(:reservations)
        .where(reservations: { date: @period_start..@period_end, cancelled: false })
        .where.not(id: already_invoiced_user_ids)
        .distinct
        .select { |u| user_total(u) > 0 }
  end

  def already_invoiced_user_ids
    Invoice.where(period_start: @period_start).pluck(:user_id)
  end

  def user_reservations(user)
    user.reservations.where(date: @period_start..@period_end)
  end

  def user_total(user)
    user_reservations(user).where(cancelled: false).sum(:price)
  end

  def process_user(user)
    if Invoice.exists?(user: user, period_start: @period_start)
      @results[:skipped] += 1
      return
    end

    person_id = @client.find_or_create_person(user)
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

    create_local_line_items(invoice, reservations, items)

    @results[:created] += 1
  end

  def build_line_items(reservations, language)
    reservations.map do |reservation|
      builder = InvoiceLineItemBuilder.new(reservation, language)
      {
        reservation: reservation,
        description: builder.build_description,
        unit_price: builder.unit_price
      }
    end
  end

  def create_local_line_items(invoice, reservations, items)
    items.each do |item|
      InvoiceLineItem.create!(
        invoice: invoice,
        reservation: item[:reservation],
        description: item[:description],
        unit_price: item[:unit_price]
      )
    end
  end
end
```

**Step 3: Run tests**

Run: `bundle exec rspec spec/services/invoice_generator_spec.rb`
Expected: PASS

**Step 4: Commit**

```bash
git add spec/services/invoice_generator_spec.rb app/services/invoice_generator.rb
git commit -m "feat: add InvoiceGenerator service for monthly invoice runs"
```

---

## Phase 4: Admin Interface

### Task 12: Create Admin InvoicesController

**Files:**
- Create: `app/controllers/admin/invoices_controller.rb`
- Create: `spec/requests/admin/invoices_spec.rb`

**Step 1: Create controller**

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

      @stats = {
        total_open: Invoice.open.sum(:total_amount),
        count_by_status: Invoice.group(:status).count
      }
    end

    def new
      @available_months = available_months_for_invoicing
    end

    def preview
      period = parse_period(params[:period])
      generator = InvoiceGenerator.new(period[:start], period[:end])
      @preview = generator.preview
      @period = period
    end

    def run
      period = parse_period(params[:period])
      generator = InvoiceGenerator.new(period[:start], period[:end])
      @result = generator.generate

      redirect_to admin_invoices_path, notice: generation_notice(@result)
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

    def available_months_for_invoicing
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

    def generation_notice(result)
      "Created #{result[:created]} invoices, skipped #{result[:skipped]}"
    end

    def sync_invoice_status(invoice)
      return unless invoice.cashctrl_invoice_id

      client = CashctrlClient.new
      data = client.get_invoice(invoice.cashctrl_invoice_id)

      # CashCtrl status mapping (adjust IDs based on your CashCtrl setup)
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

**Step 2: Add routes**

Add to `config/routes.rb`:

```ruby
namespace :admin do
  resources :invoices, only: [:index, :new, :show] do
    collection do
      get :preview
      post :run
      post :refresh_all
    end
    member do
      post :send_email
      get :download_pdf
      post :refresh_status
    end
  end
end
```

**Step 3: Commit**

```bash
git add app/controllers/admin/invoices_controller.rb config/routes.rb
git commit -m "feat: add Admin::InvoicesController with invoice management actions"
```

---

### Task 13: Create Invoice Views

**Files:**
- Create: `app/views/admin/invoices/index.html.erb`
- Create: `app/views/admin/invoices/new.html.erb`
- Create: `app/views/admin/invoices/preview.html.erb`

**Step 1: Create index view**

```erb
<%# app/views/admin/invoices/index.html.erb %>
<h1>Invoices</h1>

<div class="stats">
  <p>Open Amount: <%= number_to_currency(@stats[:total_open], unit: 'CHF ') %></p>
  <p>
    <% @stats[:count_by_status].each do |status, count| %>
      <%= status.capitalize %>: <%= count %> |
    <% end %>
  </p>
</div>

<p><%= link_to 'Generate New Invoices', new_admin_invoice_path, class: 'btn' %></p>
<p><%= button_to 'Refresh All Statuses', refresh_all_admin_invoices_path, method: :post, class: 'btn' %></p>

<table>
  <thead>
    <tr>
      <th>User</th>
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

**Step 2: Create new/run view**

```erb
<%# app/views/admin/invoices/new.html.erb %>
<h1>Generate Invoices</h1>

<%= form_tag preview_admin_invoices_path, method: :get do %>
  <div>
    <label>Select Month:</label>
    <%= select_tag :period, options_for_select(@available_months.map { |m| [m[:label], m[:start].to_s] }) %>
  </div>
  <div>
    <%= submit_tag 'Preview', class: 'btn' %>
  </div>
<% end %>
```

**Step 3: Create preview view**

```erb
<%# app/views/admin/invoices/preview.html.erb %>
<h1>Invoice Preview - <%= @period[:start].strftime('%B %Y') %></h1>

<% if @preview.any? %>
  <table>
    <thead>
      <tr>
        <th>User</th>
        <th>Reservations</th>
        <th>Total</th>
      </tr>
    </thead>
    <tbody>
      <% @preview.each do |item| %>
        <tr>
          <td><%= item[:user].email %></td>
          <td><%= item[:reservation_count] %></td>
          <td><%= number_to_currency(item[:total_amount], unit: 'CHF ') %></td>
        </tr>
      <% end %>
    </tbody>
  </table>

  <p>Total: <%= @preview.count %> invoices, <%= number_to_currency(@preview.sum { |i| i[:total_amount] }, unit: 'CHF ') %></p>

  <%= button_to 'Generate Invoices', run_admin_invoices_path(period: @period[:start]), method: :post, class: 'btn btn-primary' %>
<% else %>
  <p>No users eligible for invoicing this period.</p>
<% end %>

<p><%= link_to 'Back', new_admin_invoice_path %></p>
```

**Step 4: Commit**

```bash
git add app/views/admin/invoices/
git commit -m "feat: add admin invoice views"
```

---

### Task 14: Create Invoice Policy

**Files:**
- Create: `app/policies/invoice_policy.rb`

**Step 1: Create policy**

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

**Step 2: Commit**

```bash
git add app/policies/invoice_policy.rb
git commit -m "feat: add InvoicePolicy for authorization"
```

---

## Phase 5: Background Jobs

### Task 15: Create Invoice Status Sync Job

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

### Task 16: Add Rake Task for Scheduler

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

### Task 17: Add Navigation Link

**Files:**
- Modify: `app/views/layouts/_navigation.html.erb` (or equivalent)

Add admin nav link:
```erb
<% if current_user&.admin? %>
  <%= link_to 'Invoices', admin_invoices_path %>
<% end %>
```

**Commit:**

```bash
git add app/views/layouts/
git commit -m "feat: add Invoices link to admin navigation"
```

---

### Task 18: Run Full Test Suite

**Step 1: Run all tests**

Run: `bundle exec rspec`
Expected: All new tests PASS

**Step 2: Final commit**

```bash
git add -A
git commit -m "feat: complete CashCtrl invoicing integration"
```

---

## Summary

| Phase | Tasks | Description |
|-------|-------|-------------|
| 1 | 1-5 | Database migrations and models |
| 2 | 6-9 | CashCtrl API client |
| 3 | 10-11 | Invoice generation service |
| 4 | 12-14 | Admin interface |
| 5 | 15-16 | Background jobs |
| 6 | 17-18 | Final integration |

**Total Tasks:** 18
**Estimated Implementation:** TDD approach with frequent commits
