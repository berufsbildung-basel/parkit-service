# Billing Period Tracking Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `BillingPeriod` model to track the state of each month's billing run with audit trail, error tracking, and an improved admin dashboard.

**Architecture:** New `BillingPeriod` model (one record per month) created/updated by `BillingRunner`. Dashboard replaces stats with a billing period table. Detail page per period shows invoices. Run dropdown hides completed months.

**Tech Stack:** Rails 7.1, PostgreSQL, ERB, Spectrum CSS, Pundit, RSpec

**Worktree:** `/Users/dj/adobe/github/berufsbildung-basel/parkit-service/.worktrees/cashctrl-invoicing/`

**Spec:** `docs/superpowers/specs/2026-03-15-billing-period-tracking-design.md`

---

## Chunk 1: Model and Service

### Task 1: Create BillingPeriod Migration and Model

**Files:**
- Create: `db/migrate/TIMESTAMP_create_billing_periods.rb`
- Create: `app/models/billing_period.rb`
- Modify: `app/models/user.rb:12` (add association)
- Create: `spec/models/billing_period_spec.rb`

- [ ] **Step 1: Write failing model test**

Create `spec/models/billing_period_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BillingPeriod, type: :model do
  let(:admin) { User.create!(username: 'admin_user', email: 'admin@example.com', first_name: 'Admin', last_name: 'User', role: :admin) }

  describe 'validations' do
    it 'requires period_start' do
      bp = BillingPeriod.new(period_end: Date.new(2026, 1, 31))
      expect(bp).not_to be_valid
      expect(bp.errors[:period_start]).to be_present
    end

    it 'requires period_end' do
      bp = BillingPeriod.new(period_start: Date.new(2026, 1, 1))
      expect(bp).not_to be_valid
      expect(bp.errors[:period_end]).to be_present
    end

    it 'enforces unique period_start' do
      BillingPeriod.create!(period_start: Date.new(2026, 1, 1), period_end: Date.new(2026, 1, 31))
      duplicate = BillingPeriod.new(period_start: Date.new(2026, 1, 1), period_end: Date.new(2026, 1, 31))
      expect(duplicate).not_to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to executed_by user' do
      bp = BillingPeriod.create!(
        period_start: Date.new(2026, 1, 1),
        period_end: Date.new(2026, 1, 31),
        executed_by: admin
      )
      expect(bp.executed_by).to eq(admin)
    end
  end

  describe 'enums' do
    it 'has correct status values' do
      expect(BillingPeriod.statuses).to eq(
        'unbilled' => 0, 'in_progress' => 1, 'completed' => 2, 'partially_failed' => 3
      )
    end
  end

  describe 'scopes' do
    it 'returns completed billing periods' do
      completed = BillingPeriod.create!(period_start: Date.new(2026, 1, 1), period_end: Date.new(2026, 1, 31), status: :completed)
      BillingPeriod.create!(period_start: Date.new(2026, 2, 1), period_end: Date.new(2026, 2, 28), status: :unbilled)

      expect(BillingPeriod.completed).to contain_exactly(completed)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/dj/adobe/github/berufsbildung-basel/parkit-service/.worktrees/cashctrl-invoicing && bundle exec rspec spec/models/billing_period_spec.rb -v`
Expected: FAIL - uninitialized constant BillingPeriod

- [ ] **Step 3: Generate migration**

Run: `cd /Users/dj/adobe/github/berufsbildung-basel/parkit-service/.worktrees/cashctrl-invoicing && bundle exec rails generate migration CreateBillingPeriods`

Then replace the generated migration content with:

```ruby
# frozen_string_literal: true

class CreateBillingPeriods < ActiveRecord::Migration[7.1]
  def change
    create_table :billing_periods, id: :uuid do |t|
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.integer :status, null: false, default: 0
      t.integer :invoices_created, null: false, default: 0
      t.integer :invoices_skipped, null: false, default: 0
      t.integer :journal_entries_created, null: false, default: 0
      t.integer :topup_invoices_created, null: false, default: 0
      t.integer :exempt_skipped, null: false, default: 0
      t.jsonb :errors_log, null: false, default: []
      t.references :executed_by, null: true, foreign_key: { to_table: :users }, type: :uuid
      t.datetime :executed_at

      t.timestamps
    end

    add_index :billing_periods, :period_start, unique: true
    add_index :billing_periods, :status
  end
end
```

Note: Column is named `errors_log` instead of `errors` to avoid conflict with ActiveRecord's `errors` method.

- [ ] **Step 4: Run migration**

Run: `cd /Users/dj/adobe/github/berufsbildung-basel/parkit-service/.worktrees/cashctrl-invoicing && bundle exec rails db:migrate`

- [ ] **Step 5: Create model**

Create `app/models/billing_period.rb`:

```ruby
# frozen_string_literal: true

class BillingPeriod < ApplicationRecord
  belongs_to :executed_by, class_name: 'User', optional: true

  enum status: { unbilled: 0, in_progress: 1, completed: 2, partially_failed: 3 }

  validates :period_start, presence: true, uniqueness: true
  validates :period_end, presence: true
end
```

- [ ] **Step 6: Add association to User model**

In `app/models/user.rb`, add after line 12 (`has_many :journal_entries, dependent: :destroy`):

```ruby
  has_many :executed_billing_periods, class_name: 'BillingPeriod', foreign_key: :executed_by_id, dependent: :nullify
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `cd /Users/dj/adobe/github/berufsbildung-basel/parkit-service/.worktrees/cashctrl-invoicing && bundle exec rspec spec/models/billing_period_spec.rb -v`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add db/migrate/*_create_billing_periods.rb app/models/billing_period.rb app/models/user.rb spec/models/billing_period_spec.rb db/schema.rb
git commit -m "feat: add BillingPeriod model for tracking monthly billing state"
```

---

### Task 2: Integrate BillingPeriod into BillingRunner

**Files:**
- Modify: `app/services/billing_runner.rb:18-28` (constructor) and `30-38` (run method)
- Modify: `spec/services/billing_runner_spec.rb` (add BillingPeriod assertions)

- [ ] **Step 1: Write failing tests for BillingPeriod integration**

Add to `spec/services/billing_runner_spec.rb`, inside the `describe 'standard users'` block (after the existing `it 'skips already invoiced users'` test around line 96):

```ruby
    it 'creates a completed BillingPeriod record' do
      runner = described_class.new(period_start, period_end, executed_by: admin)
      runner.run

      bp = BillingPeriod.find_by(period_start: period_start)
      expect(bp).to be_present
      expect(bp.status).to eq('completed')
      expect(bp.invoices_created).to eq(1)
      expect(bp.executed_by).to eq(admin)
      expect(bp.executed_at).to be_present
    end
```

Also add `let(:admin)` near the top of the describe block (after `let(:cashctrl_client)`):

```ruby
  let(:admin) { User.create!(username: 'admin_user', email: 'admin@example.com', first_name: 'Admin', last_name: 'User', role: :admin) }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/dj/adobe/github/berufsbildung-basel/parkit-service/.worktrees/cashctrl-invoicing && bundle exec rspec spec/services/billing_runner_spec.rb -v`
Expected: FAIL - wrong number of arguments

- [ ] **Step 3: Update BillingRunner constructor and run method**

In `app/services/billing_runner.rb`, replace lines 18-38:

```ruby
  def initialize(period_start, period_end, executed_by: nil)
    @period_start = period_start
    @period_end = period_end
    @executed_by = executed_by
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
    @billing_period = find_or_create_billing_period!

    process_standard_users
    process_prepaid_users
    process_exempt_users

    finalize_billing_period!
    @results
  end
```

Add these private methods at the end of the class (before the final `end`):

```ruby
  def find_or_create_billing_period!
    bp = BillingPeriod.find_or_initialize_by(period_start: @period_start)
    bp.update!(
      period_end: @period_end,
      status: :in_progress,
      executed_by: @executed_by,
      invoices_created: 0,
      invoices_skipped: 0,
      journal_entries_created: 0,
      topup_invoices_created: 0,
      exempt_skipped: 0,
      errors_log: []
    )
    bp
  end

  def finalize_billing_period!
    @billing_period.update!(
      status: @results[:errors].empty? ? :completed : :partially_failed,
      invoices_created: @results[:standard][:created],
      invoices_skipped: @results[:standard][:skipped],
      journal_entries_created: @results[:prepaid][:journal_entries_created],
      topup_invoices_created: @results[:prepaid][:topup_invoices_created],
      exempt_skipped: @results[:exempt][:skipped],
      errors_log: @results[:errors],
      executed_at: Time.current
    )
  end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/dj/adobe/github/berufsbildung-basel/parkit-service/.worktrees/cashctrl-invoicing && bundle exec rspec spec/services/billing_runner_spec.rb -v`
Expected: PASS (all existing + new test)

- [ ] **Step 5: Commit**

```bash
git add app/services/billing_runner.rb spec/services/billing_runner_spec.rb
git commit -m "feat: integrate BillingPeriod tracking into BillingRunner"
```

---

## Chunk 2: Controller, Views, and Routes

### Task 3: Add BillingPeriod Routes, Controller, and Policy

**Files:**
- Modify: `config/routes.rb:44` (add billing_periods route inside admin namespace)
- Create: `app/controllers/admin/billing_periods_controller.rb`
- Create: `app/policies/billing_period_policy.rb`
- Modify: `app/controllers/admin/billing_controller.rb` (pass current_user to BillingRunner, update show/run actions)

- [ ] **Step 1: Add route**

In `config/routes.rb`, inside the `namespace :admin` block (after the `resources :journal_entries` line), add:

```ruby
    resources :billing_periods, only: [:show]
```

- [ ] **Step 2: Create Pundit policy**

Create `app/policies/billing_period_policy.rb`:

```ruby
# frozen_string_literal: true

class BillingPeriodPolicy < ApplicationPolicy
  def show?
    user&.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user&.admin?
        scope.all
      else
        scope.none
      end
    end
  end
end
```

- [ ] **Step 3: Create controller**

Create `app/controllers/admin/billing_periods_controller.rb`:

```ruby
# frozen_string_literal: true

module Admin
  class BillingPeriodsController < BaseController
    def show
      @billing_period = BillingPeriod.find(params[:id])
      @invoices = Invoice.includes(:user)
                         .for_period(@billing_period.period_start)
                         .order(created_at: :desc)
    end
  end
end
```

- [ ] **Step 4: Update BillingController**

In `app/controllers/admin/billing_controller.rb`, replace the `show` method (lines 5-11):

```ruby
    def show
      @billing_periods = BillingPeriod.order(period_start: :desc)
      @stats = {
        total_open: Invoice.open.sum(:total_amount)
      }
    end
```

Replace the `execute` method (lines 24-30):

```ruby
    def execute
      period = parse_period(params[:period])
      runner = BillingRunner.new(period[:start], period[:end], executed_by: current_user)
      @result = runner.run

      redirect_to admin_billing_path, notice: billing_notice(@result)
    end
```

Replace `available_months_for_billing` (lines 34-46) to exclude completed months:

```ruby
    def available_months_for_billing
      billing_start = Rails.application.config.cashctrl[:billing_start_date] || 6.months.ago.to_date
      start_month = billing_start.beginning_of_month
      end_month = 1.month.ago.beginning_of_month

      completed_months = BillingPeriod.completed.pluck(:period_start)

      months = []
      current = end_month
      while current >= start_month
        unless completed_months.include?(current)
          months << { start: current, end: current.end_of_month, label: current.strftime('%B %Y') }
        end
        current -= 1.month
      end
      months
    end
```

- [ ] **Step 5: Commit**

```bash
git add config/routes.rb app/controllers/admin/billing_periods_controller.rb app/policies/billing_period_policy.rb app/controllers/admin/billing_controller.rb
git commit -m "feat: add BillingPeriod controller, routes, policy, and update BillingController"
```

---

### Task 4: Update Dashboard and Create Detail View

**Files:**
- Modify: `app/views/admin/billing/show.html.erb` (replace stats with billing period table)
- Create: `app/views/admin/billing_periods/show.html.erb`

- [ ] **Step 1: Replace dashboard view**

Replace the entire content of `app/views/admin/billing/show.html.erb`:

```erb
<% content_for :title, 'Billing Dashboard' %>

<section class="spectrum-CSSComponent-description">
  <h2 class="spectrum-Heading spectrum-Heading--sizeM">Billing Dashboard</h2>
  <hr class="spectrum-Divider spectrum-Divider--large" style="margin-bottom: 1.5rem;">

  <div class="spectrum-Body spectrum-Body--sizeM">
    <%= render 'admin/shared/cashctrl_status' %>

    <p><strong>Open Invoice Amount:</strong> <%= number_to_currency(@stats[:total_open], unit: 'CHF ') %></p>

    <h3 class="spectrum-Heading spectrum-Heading--sizeS" style="margin-top: 1.5rem;">Billing Periods</h3>
    <% if @billing_periods.any? %>
      <table class="spectrum-Table spectrum-Table--sizeM">
        <thead class="spectrum-Table-head">
          <tr>
            <th class="spectrum-Table-headCell">Period</th>
            <th class="spectrum-Table-headCell">Status</th>
            <th class="spectrum-Table-headCell">Invoices</th>
            <th class="spectrum-Table-headCell">Journal Entries</th>
            <th class="spectrum-Table-headCell">Top-ups</th>
            <th class="spectrum-Table-headCell">Errors</th>
            <th class="spectrum-Table-headCell">Executed By</th>
            <th class="spectrum-Table-headCell">Executed At</th>
          </tr>
        </thead>
        <tbody class="spectrum-Table-body">
          <% @billing_periods.each do |bp| %>
            <tr class="spectrum-Table-row">
              <td class="spectrum-Table-cell">
                <%= link_to bp.period_start.strftime('%B %Y'), admin_billing_period_path(bp), class: 'spectrum-Link' %>
              </td>
              <td class="spectrum-Table-cell">
                <%
                  bg = case bp.status
                       when 'completed' then '#2d9d78'
                       when 'partially_failed' then '#e68619'
                       when 'in_progress' then '#4b9cf5'
                       else '#b1b1b1'
                       end
                %>
                <span style="display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 12px; background-color: <%= bg %>; color: white;">
                  <%= bp.status.humanize %>
                </span>
              </td>
              <td class="spectrum-Table-cell"><%= bp.invoices_created %></td>
              <td class="spectrum-Table-cell"><%= bp.journal_entries_created %></td>
              <td class="spectrum-Table-cell"><%= bp.topup_invoices_created %></td>
              <td class="spectrum-Table-cell"><%= bp.errors_log.size %></td>
              <td class="spectrum-Table-cell"><%= bp.executed_by&.email || '-' %></td>
              <td class="spectrum-Table-cell"><%= bp.executed_at&.strftime('%d.%m.%Y %H:%M') || '-' %></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    <% else %>
      <p>No billing periods yet. Use "Run Billing" to create your first one.</p>
    <% end %>
  </div>

  <div class="spectrum-ButtonGroup" style="margin-top: 1.5rem;">
    <%= link_to 'Run Billing', run_admin_billing_path,
        class: 'spectrum-Button spectrum-Button--fill spectrum-Button--accent spectrum-Button--sizeM' %>
    <%= link_to 'View All Invoices', admin_invoices_path,
        class: 'spectrum-Button spectrum-Button--fill spectrum-Button--secondary spectrum-Button--sizeM' %>
    <%= link_to 'View Journal Entries', admin_journal_entries_path,
        class: 'spectrum-Button spectrum-Button--fill spectrum-Button--secondary spectrum-Button--sizeM' %>
    <%= button_to 'Refresh All Statuses', refresh_all_admin_invoices_path, method: :post,
        class: 'spectrum-Button spectrum-Button--fill spectrum-Button--secondary spectrum-Button--sizeM' %>
  </div>
</section>
```

- [ ] **Step 2: Create billing period detail view**

Create directory and file `app/views/admin/billing_periods/show.html.erb`:

```erb
<% content_for :title, "Billing Period - #{@billing_period.period_start.strftime('%B %Y')}" %>

<section class="spectrum-CSSComponent-description">
  <h2 class="spectrum-Heading spectrum-Heading--sizeM">Billing Period - <%= @billing_period.period_start.strftime('%B %Y') %></h2>
  <hr class="spectrum-Divider spectrum-Divider--large" style="margin-bottom: 1.5rem;">

  <div class="spectrum-Body spectrum-Body--sizeM">
    <%
      bg = case @billing_period.status
           when 'completed' then '#2d9d78'
           when 'partially_failed' then '#e68619'
           when 'in_progress' then '#4b9cf5'
           else '#b1b1b1'
           end
    %>
    <p>
      <span style="display: inline-block; padding: 4px 12px; border-radius: 4px; font-size: 13px; background-color: <%= bg %>; color: white;">
        &#9679; <%= @billing_period.status.humanize %>
      </span>
    </p>

    <table class="spectrum-Table spectrum-Table--sizeM" style="max-width: 400px;">
      <tbody class="spectrum-Table-body">
        <tr class="spectrum-Table-row">
          <td class="spectrum-Table-cell"><strong>Invoices Created</strong></td>
          <td class="spectrum-Table-cell"><%= @billing_period.invoices_created %></td>
        </tr>
        <tr class="spectrum-Table-row">
          <td class="spectrum-Table-cell"><strong>Invoices Skipped</strong></td>
          <td class="spectrum-Table-cell"><%= @billing_period.invoices_skipped %></td>
        </tr>
        <tr class="spectrum-Table-row">
          <td class="spectrum-Table-cell"><strong>Journal Entries</strong></td>
          <td class="spectrum-Table-cell"><%= @billing_period.journal_entries_created %></td>
        </tr>
        <tr class="spectrum-Table-row">
          <td class="spectrum-Table-cell"><strong>Top-up Invoices</strong></td>
          <td class="spectrum-Table-cell"><%= @billing_period.topup_invoices_created %></td>
        </tr>
        <tr class="spectrum-Table-row">
          <td class="spectrum-Table-cell"><strong>Exempt Skipped</strong></td>
          <td class="spectrum-Table-cell"><%= @billing_period.exempt_skipped %></td>
        </tr>
        <tr class="spectrum-Table-row">
          <td class="spectrum-Table-cell"><strong>Executed By</strong></td>
          <td class="spectrum-Table-cell"><%= @billing_period.executed_by&.email || '-' %></td>
        </tr>
        <tr class="spectrum-Table-row">
          <td class="spectrum-Table-cell"><strong>Executed At</strong></td>
          <td class="spectrum-Table-cell"><%= @billing_period.executed_at&.strftime('%d.%m.%Y %H:%M') || '-' %></td>
        </tr>
      </tbody>
    </table>

    <% if @billing_period.errors_log.any? %>
      <h3 class="spectrum-Heading spectrum-Heading--sizeS" style="margin-top: 1.5rem;">Errors</h3>
      <table class="spectrum-Table spectrum-Table--sizeM">
        <thead class="spectrum-Table-head">
          <tr>
            <th class="spectrum-Table-headCell">User</th>
            <th class="spectrum-Table-headCell">Type</th>
            <th class="spectrum-Table-headCell">Error</th>
          </tr>
        </thead>
        <tbody class="spectrum-Table-body">
          <% @billing_period.errors_log.each do |err| %>
            <tr class="spectrum-Table-row">
              <td class="spectrum-Table-cell"><%= User.find_by(id: err['user_id'])&.email || err['user_id'] %></td>
              <td class="spectrum-Table-cell"><%= err['type'] %></td>
              <td class="spectrum-Table-cell"><%= err['error'] %></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    <% end %>

    <% if @invoices.any? %>
      <h3 class="spectrum-Heading spectrum-Heading--sizeS" style="margin-top: 1.5rem;">Invoices</h3>
      <table class="spectrum-Table spectrum-Table--sizeM">
        <thead class="spectrum-Table-head">
          <tr>
            <th class="spectrum-Table-headCell">User</th>
            <th class="spectrum-Table-headCell">Amount</th>
            <th class="spectrum-Table-headCell">Status</th>
            <th class="spectrum-Table-headCell">Sent</th>
            <th class="spectrum-Table-headCell">Actions</th>
          </tr>
        </thead>
        <tbody class="spectrum-Table-body">
          <% @invoices.each do |invoice| %>
            <tr class="spectrum-Table-row">
              <td class="spectrum-Table-cell"><%= link_to invoice.user.email, admin_invoice_path(invoice), class: 'spectrum-Link' %></td>
              <td class="spectrum-Table-cell"><%= number_to_currency(invoice.total_amount, unit: 'CHF ') %></td>
              <td class="spectrum-Table-cell"><%= invoice.status.capitalize %></td>
              <td class="spectrum-Table-cell"><%= invoice.sent_at&.strftime('%d.%m.%Y') || '-' %></td>
              <td class="spectrum-Table-cell">
                <div class="spectrum-ButtonGroup">
                  <% unless invoice.sent? || invoice.paid? %>
                    <%= button_to 'Send', send_email_admin_invoice_path(invoice), method: :post,
                        class: 'spectrum-Button spectrum-Button--fill spectrum-Button--accent spectrum-Button--sizeS' %>
                  <% end %>
                  <%= link_to 'PDF', download_pdf_admin_invoice_path(invoice),
                      class: 'spectrum-Button spectrum-Button--fill spectrum-Button--secondary spectrum-Button--sizeS' %>
                </div>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    <% end %>

    <div style="margin-top: 1.5rem;">
      <%= link_to 'Back to Billing', admin_billing_path,
          class: 'spectrum-Button spectrum-Button--fill spectrum-Button--secondary spectrum-Button--sizeM' %>
    </div>
  </div>
</section>
```

- [ ] **Step 3: Run full test suite**

Run: `cd /Users/dj/adobe/github/berufsbildung-basel/parkit-service/.worktrees/cashctrl-invoicing && bundle exec rspec spec/ -v 2>&1 | tail -20`
Expected: All tests pass (0 failures)

- [ ] **Step 4: Commit**

```bash
git add app/views/admin/billing/show.html.erb app/views/admin/billing_periods/show.html.erb
git commit -m "feat: add billing period dashboard and detail view"
```
