# CashCtrl Invoicing - Remaining Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the last 4 gaps in the CashCtrl invoicing feature: user billing view with invoice records, preferred_language in profile form, admin invoice filters, and config fix.

**Architecture:** All changes are in the existing cashctrl-invoicing worktree. Tasks are independent and can be parallelized. Views use Spectrum CSS (Adobe's design system). The app is Rails 7.1 with ERB templates, Pundit authorization, and Kaminari pagination.

**Tech Stack:** Rails 7.1, ERB, Spectrum CSS, Pundit, Kaminari, RSpec

**Worktree:** `/Users/dj/adobe/github/berufsbildung-basel/parkit-service/.worktrees/cashctrl-invoicing/`

---

## Chunk 1: All Tasks

### Task 1: User Billing View - Show Invoice Records with PDF Links

The current user billing view (`/users/:id/billing`) only shows reservation aggregates grouped by month. It needs to show actual `Invoice` records with status, amount, and PDF download links.

**Files:**
- Modify: `app/controllers/user_billing_controller.rb`
- Modify: `app/views/user_billing/index.html.erb`
- Modify: `config/routes.rb:23` (add `download_pdf` member route for user invoices)
- Create: `app/controllers/user_invoice_downloads_controller.rb`
- Modify: `app/policies/invoice_policy.rb` (add user-scoped `download_pdf?`)
- Create: `spec/controllers/user_billing_controller_spec.rb`

**Context:**
- `Invoice` model: `belongs_to :user`, has `status` enum (draft/sent/paid/cancelled), `total_amount`, `period_start`, `sent_at`, `paid_at`, `cashctrl_invoice_id`
- `CashctrlClient#get_invoice_pdf(id)` returns binary PDF data
- Current admin PDF download is at `Admin::InvoicesController#download_pdf` (app/controllers/admin/invoices_controller.rb:24-31)
- Users should only see their own invoices and download their own PDFs
- The view should keep the existing reservation summary AND add an invoice section below it

- [ ] **Step 1: Write failing test for controller**

Create `spec/controllers/user_billing_controller_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserBillingController, type: :controller do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  before { sign_in user }

  describe 'GET #index' do
    let!(:invoice) do
      create(:invoice, user: user, period_start: Date.new(2026, 1, 1),
             period_end: Date.new(2026, 1, 31), total_amount: 120.0,
             status: :sent, cashctrl_person_id: 1)
    end
    let!(:other_invoice) do
      create(:invoice, user: other_user, period_start: Date.new(2026, 1, 1),
             period_end: Date.new(2026, 1, 31), total_amount: 80.0,
             cashctrl_person_id: 2)
    end

    it 'assigns invoices for the requested user' do
      get :index, params: { user_id: user.id }
      expect(assigns(:invoices)).to include(invoice)
      expect(assigns(:invoices)).not_to include(other_invoice)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/controllers/user_billing_controller_spec.rb -v`
Expected: FAIL - `@invoices` is nil or not assigned

- [ ] **Step 3: Update controller to load invoices**

Modify `app/controllers/user_billing_controller.rb`:

```ruby
# frozen_string_literal: true

class UserBillingController < AuthorizableController
  def index
    @user = User.find(params[:user_id])
    authorize @user, :show?
    @reservations = policy_scope(@user.reservations.active.order(date: 'desc')).group_by do |reservation|
      reservation.date.end_of_month
    end
    @invoices = @user.invoices.order(period_start: :desc)
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/controllers/user_billing_controller_spec.rb -v`
Expected: PASS

- [ ] **Step 5: Update view to show invoices**

Replace `app/views/user_billing/index.html.erb` with:

```erb
<%
  content_for :title, 'My Billing'
%>
<section class="spectrum-CSSComponent-description">
  <h3 class="spectrum-Heading spectrum-Heading--sizeS">Invoices</h3>
  <% if @invoices.any? %>
    <table class="spectrum-Table spectrum-Table--sizeM">
      <thead class="spectrum-Table-head">
      <tr>
        <th class="spectrum-Table-headCell">Period</th>
        <th class="spectrum-Table-headCell">Amount</th>
        <th class="spectrum-Table-headCell">Status</th>
        <th class="spectrum-Table-headCell">Sent</th>
        <th class="spectrum-Table-headCell">PDF</th>
      </tr>
      </thead>
      <tbody class="spectrum-Table-body">
      <% @invoices.each do |invoice| %>
        <tr class="spectrum-Table-row">
          <td class="spectrum-Table-cell"><%= invoice.period_start.strftime('%B %Y') %></td>
          <td class="spectrum-Table-cell"><%= number_to_currency(invoice.total_amount, unit: 'CHF ') %></td>
          <td class="spectrum-Table-cell"><%= invoice.status.capitalize %></td>
          <td class="spectrum-Table-cell"><%= invoice.sent_at&.strftime('%d.%m.%Y') || '-' %></td>
          <td class="spectrum-Table-cell">
            <% if invoice.cashctrl_invoice_id.present? %>
              <%= link_to 'Download',
                  user_invoice_download_path(@user, invoice),
                  class: 'spectrum-Link' %>
            <% end %>
          </td>
        </tr>
      <% end %>
      </tbody>
    </table>
  <% else %>
    <p class="spectrum-Body spectrum-Body--sizeM">No invoices yet.</p>
  <% end %>

  <h3 class="spectrum-Heading spectrum-Heading--sizeS" style="margin-top: 2rem;">Reservation History</h3>
  <div class="spectrum-Body spectrum-Body--sizeM">
    <p>Months with reservations in reverse chronological order with the total amount of charges.</p>
  </div>
  <% if @reservations.any? %>
    <table class="spectrum-Table spectrum-Table--sizeM">
      <thead class="spectrum-Table-head">
      <tr>
        <th class="spectrum-Table-headCell">Month</th>
        <th class="spectrum-Table-headCell">Reservations</th>
        <th class="spectrum-Table-headCell">Total CHF</th>
        <th class="spectrum-Table-headCell">Status</th>
      </tr>
      </thead>
      <tbody class="spectrum-Table-body">
      <% @reservations.each do |month, reservations| %>
        <tr class="spectrum-Table-row">
          <td class="spectrum-Table-cell"><strong><%= month.strftime('%b %Y') %></strong></td>
          <td class="spectrum-Table-cell"><%= reservations.count %></td>
          <td class="spectrum-Table-cell"><%= reservations.sum(&:price) %></td>
          <td class="spectrum-Table-cell"><%= Date.today > month ? 'Final' : 'Accruing' %></td>
        </tr>
      <% end %>
      </tbody>
    </table>
  <% else %>
    <p>No reservation data yet.</p>
  <% end %>
</section>
```

- [ ] **Step 6: Add user PDF download route and controller**

Add route in `config/routes.rb` inside the `resources :users` block (after line 23):

```ruby
resources :users do
  resources :reservations do
    put 'cancel', action: 'cancel'
  end
  resources :vehicles, controller: 'user_vehicles' do
    resources :reservations
  end
  get 'billing', controller: 'user_billing', action: 'index'
  resources :invoice_downloads, only: [:show], controller: 'user_invoice_downloads'
end
```

Create `app/controllers/user_invoice_downloads_controller.rb`:

```ruby
# frozen_string_literal: true

class UserInvoiceDownloadsController < AuthorizableController
  def show
    @user = User.find(params[:user_id])
    authorize @user, :show?
    invoice = @user.invoices.find(params[:id])

    client = CashctrlClient.new
    pdf_data = client.get_invoice_pdf(invoice.cashctrl_invoice_id)

    send_data pdf_data,
              filename: "invoice-#{invoice.period_start.strftime('%Y-%m')}.pdf",
              type: 'application/pdf',
              disposition: 'attachment'
  rescue StandardError => e
    Rails.logger.error("PDF download failed: #{e.message}")
    redirect_to user_billing_path(@user), alert: 'Failed to download PDF.'
  end
end
```

- [ ] **Step 7: Verify manually and commit**

Run: `bundle exec rspec spec/controllers/user_billing_controller_spec.rb -v`
Expected: PASS

```bash
git add app/controllers/user_billing_controller.rb \
  app/views/user_billing/index.html.erb \
  app/controllers/user_invoice_downloads_controller.rb \
  spec/controllers/user_billing_controller_spec.rb \
  config/routes.rb
git commit -m "feat: add invoice records with PDF download to user billing view"
```

---

### Task 2: Add Preferred Language to Profile Edit Form

The `preferred_language` field is already in the User model (column exists since initial migration, default `'en'`), and the `ProfileController` already permits it. But the edit form is missing the select field.

**Files:**
- Modify: `app/views/profile/edit.html.erb:63` (before `</fieldset>`)
- Modify: `app/views/profile/show.html.erb` (add language display)
- Modify: `app/helpers/profile_helper.rb` (add language options helper)
- Modify: `config/locales/en.yml` (add translation keys)

- [ ] **Step 1: Add language options helper**

Modify `app/helpers/profile_helper.rb` to add:

```ruby
# frozen_string_literal: true

module ProfileHelper
  def country_options_for_select
    [
      %w[Switzerland CH],
      %w[Germany DE],
      %w[France FR],
      %w[Austria AT],
      %w[Italy IT],
      %w[Liechtenstein LI]
    ]
  end

  def language_options_for_select
    [
      %w[English en],
      %w[Deutsch de],
      ['Français', 'fr'],
      %w[Italiano it]
    ]
  end
end
```

- [ ] **Step 2: Add language field to edit form**

In `app/views/profile/edit.html.erb`, insert after the `country_code` form item (after line 63, before `</fieldset>`):

```erb
      <div class="spectrum-Form-item">
        <%= f.label :preferred_language, t('.preferred_language'), class: 'spectrum-FieldLabel spectrum-FieldLabel--sizeM' %>
        <%= f.select :preferred_language, language_options_for_select,
            {}, class: 'spectrum-Picker-input' %>
      </div>
```

- [ ] **Step 3: Add language display to show view**

In `app/views/profile/show.html.erb`, insert after the address row (after line 35, before `</dl>`):

```erb
      <div class="spectrum-Table-row">
        <dt class="spectrum-Table-headCell"><%= t('.preferred_language') %></dt>
        <dd class="spectrum-Table-cell"><%= @user.preferred_language&.upcase || 'EN' %></dd>
      </div>
```

- [ ] **Step 4: Add locale keys**

In `config/locales/en.yml`, add under `profile.edit`:

```yaml
      preferred_language: "Invoice language"
```

And under `profile.show`:

```yaml
      preferred_language: "Invoice language"
```

- [ ] **Step 5: Verify and commit**

Run: `bundle exec rspec` (full suite to check nothing breaks)

```bash
git add app/helpers/profile_helper.rb \
  app/views/profile/edit.html.erb \
  app/views/profile/show.html.erb \
  config/locales/en.yml
git commit -m "feat: add preferred language select to profile form"
```

---

### Task 3: Admin Invoice Dashboard Filters

The admin invoices index needs filters for period (month/year), status, and user search. Currently it just lists all invoices paginated.

**Files:**
- Modify: `app/controllers/admin/invoices_controller.rb:7-12` (add filter logic to `index`)
- Modify: `app/views/admin/invoices/index.html.erb` (add filter form above table)
- Create: `spec/controllers/admin/invoices_controller_spec.rb`

- [ ] **Step 1: Write failing test for filters**

Create `spec/controllers/admin/invoices_controller_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::InvoicesController, type: :controller do
  let(:admin) { create(:user, role: :admin) }

  before { sign_in admin }

  describe 'GET #index' do
    let(:user_a) { create(:user, email: 'alice@example.com') }
    let(:user_b) { create(:user, email: 'bob@example.com') }

    let!(:jan_invoice) do
      create(:invoice, user: user_a, period_start: Date.new(2026, 1, 1),
             period_end: Date.new(2026, 1, 31), status: :sent, cashctrl_person_id: 1)
    end
    let!(:feb_invoice) do
      create(:invoice, user: user_b, period_start: Date.new(2026, 2, 1),
             period_end: Date.new(2026, 2, 28), status: :paid, cashctrl_person_id: 2)
    end

    it 'returns all invoices without filters' do
      get :index
      expect(assigns(:invoices)).to include(jan_invoice, feb_invoice)
    end

    it 'filters by period' do
      get :index, params: { period: '2026-01-01' }
      expect(assigns(:invoices)).to include(jan_invoice)
      expect(assigns(:invoices)).not_to include(feb_invoice)
    end

    it 'filters by status' do
      get :index, params: { status: 'paid' }
      expect(assigns(:invoices)).to include(feb_invoice)
      expect(assigns(:invoices)).not_to include(jan_invoice)
    end

    it 'filters by user search' do
      get :index, params: { q: 'alice' }
      expect(assigns(:invoices)).to include(jan_invoice)
      expect(assigns(:invoices)).not_to include(feb_invoice)
    end

    it 'combines filters' do
      get :index, params: { status: 'sent', q: 'alice' }
      expect(assigns(:invoices)).to include(jan_invoice)
      expect(assigns(:invoices)).not_to include(feb_invoice)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/controllers/admin/invoices_controller_spec.rb -v`
Expected: FAIL on filter tests (all invoices returned regardless of params)

- [ ] **Step 3: Add filter logic to controller**

Replace the `index` method in `app/controllers/admin/invoices_controller.rb:7-12`:

```ruby
    def index
      @invoices = Invoice.includes(:user)

      if params[:period].present?
        @invoices = @invoices.where(period_start: params[:period].to_date)
      end

      if params[:status].present?
        @invoices = @invoices.where(status: params[:status])
      end

      if params[:q].present?
        @invoices = @invoices.joins(:user).where('users.email ILIKE ?', "%#{params[:q]}%")
      end

      @invoices = @invoices.order(created_at: :desc)
                           .page(params[:page])
                           .per(25)
    end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/controllers/admin/invoices_controller_spec.rb -v`
Expected: PASS

- [ ] **Step 5: Add filter form to view**

In `app/views/admin/invoices/index.html.erb`, replace the entire file:

```erb
<h1>Invoices</h1>

<p><%= link_to 'Back to Billing', admin_billing_path %></p>

<form method="get" action="<%= admin_invoices_path %>" style="margin-bottom: 1rem; display: flex; gap: 1rem; align-items: end; flex-wrap: wrap;">
  <div>
    <label for="period"><strong>Period</strong></label><br>
    <select name="period" id="period">
      <option value="">All</option>
      <% Invoice.distinct.pluck(:period_start).sort.reverse.each do |ps| %>
        <option value="<%= ps %>" <%= 'selected' if params[:period] == ps.to_s %>><%= ps.strftime('%B %Y') %></option>
      <% end %>
    </select>
  </div>

  <div>
    <label for="status"><strong>Status</strong></label><br>
    <select name="status" id="status">
      <option value="">All</option>
      <% Invoice.statuses.keys.each do |s| %>
        <option value="<%= s %>" <%= 'selected' if params[:status] == s %>><%= s.capitalize %></option>
      <% end %>
    </select>
  </div>

  <div>
    <label for="q"><strong>User</strong></label><br>
    <input type="text" name="q" id="q" value="<%= params[:q] %>" placeholder="Search by email">
  </div>

  <div>
    <button type="submit">Filter</button>
    <% if params[:period].present? || params[:status].present? || params[:q].present? %>
      <%= link_to 'Clear', admin_invoices_path %>
    <% end %>
  </div>
</form>

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

<%= paginate @invoices if @invoices.respond_to?(:total_pages) %>
```

- [ ] **Step 6: Run all tests and commit**

Run: `bundle exec rspec spec/controllers/admin/invoices_controller_spec.rb -v`
Expected: PASS

```bash
git add app/controllers/admin/invoices_controller.rb \
  app/views/admin/invoices/index.html.erb \
  spec/controllers/admin/invoices_controller_spec.rb
git commit -m "feat: add period, status, and user search filters to admin invoices"
```

---

### Task 4: Fix Billing Period Field Default

The config currently defaults `CASHCTRL_BILLING_PERIOD_FIELD_ID` to `'customField8'` (dev value). This is wrong for prod (`customField7`). Remove the default so it must be set explicitly per environment.

**Files:**
- Modify: `config/initializers/cashctrl.rb:13`

- [ ] **Step 1: Remove the default value**

In `config/initializers/cashctrl.rb`, change line 13 from:

```ruby
  billing_period_field_id: ENV.fetch('CASHCTRL_BILLING_PERIOD_FIELD_ID', 'customField8'),
```

to:

```ruby
  billing_period_field_id: ENV.fetch('CASHCTRL_BILLING_PERIOD_FIELD_ID', nil),
```

- [ ] **Step 2: Verify tests still pass**

Run: `bundle exec rspec`
Expected: PASS (tests mock the config, so no impact)

- [ ] **Step 3: Commit**

```bash
git add config/initializers/cashctrl.rb
git commit -m "fix: remove hardcoded default for billing period custom field ID"
```
