# User Profile & Address Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow users to manage their profile and address for Swiss QR-bill invoicing.

**Architecture:** Rails stores address as source of truth, syncs one-way to CashCtrl on profile save. Dashboard shows reminder for incomplete addresses.

**Tech Stack:** Rails 7.1, RSpec, CashCtrl API, Devise, Adobe Spectrum CSS

---

## Task 1: Add Address Fields to User Model

**Files:**
- Create: `db/migrate/XXXXXX_add_address_fields_to_users.rb`
- Modify: `app/models/user.rb`
- Test: `spec/models/user_spec.rb`

**Step 1: Write the failing tests**

Add to `spec/models/user_spec.rb`:

```ruby
describe 'address fields' do
  let(:user) do
    User.create!(
      username: 'testuser',
      email: 'test@example.com',
      first_name: 'Test',
      last_name: 'User'
    )
  end

  describe '#address_complete?' do
    it 'returns false when no address fields are set' do
      expect(user.address_complete?).to be false
    end

    it 'returns false when only some address fields are set' do
      user.update(address_line1: 'Musterstrasse 1')
      expect(user.address_complete?).to be false
    end

    it 'returns true when all required address fields are set' do
      user.update(
        address_line1: 'Musterstrasse 1',
        postal_code: '4000',
        city: 'Basel',
        country_code: 'CH'
      )
      expect(user.address_complete?).to be true
    end

    it 'returns true even without address_line2' do
      user.update(
        address_line1: 'Musterstrasse 1',
        postal_code: '4000',
        city: 'Basel',
        country_code: 'CH'
      )
      expect(user.address_complete?).to be true
    end
  end

  describe '#full_address_line' do
    it 'returns address_line1 when no line2' do
      user.update(address_line1: 'Musterstrasse 1')
      expect(user.full_address_line).to eq('Musterstrasse 1')
    end

    it 'concatenates line1 and line2 with comma' do
      user.update(
        address_line1: 'Musterstrasse 1',
        address_line2: 'Apt 3B'
      )
      expect(user.full_address_line).to eq('Musterstrasse 1, Apt 3B')
    end

    it 'returns empty string when no address' do
      expect(user.full_address_line).to eq('')
    end
  end

  describe 'address validation' do
    it 'allows saving with no address fields' do
      expect(user).to be_valid
    end

    it 'requires all fields when any address field is present' do
      user.address_line1 = 'Musterstrasse 1'
      expect(user).not_to be_valid
      expect(user.errors[:postal_code]).to include("can't be blank")
      expect(user.errors[:city]).to include("can't be blank")
      expect(user.errors[:country_code]).to include("can't be blank")
    end

    it 'is valid with complete address' do
      user.assign_attributes(
        address_line1: 'Musterstrasse 1',
        postal_code: '4000',
        city: 'Basel',
        country_code: 'CH'
      )
      expect(user).to be_valid
    end

    it 'allows address_line2 to be blank' do
      user.assign_attributes(
        address_line1: 'Musterstrasse 1',
        postal_code: '4000',
        city: 'Basel',
        country_code: 'CH',
        address_line2: nil
      )
      expect(user).to be_valid
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/models/user_spec.rb:53 -f d`

Expected: FAIL with "unknown attribute 'address_line1'"

**Step 3: Generate and run migration**

```bash
bin/rails generate migration AddAddressFieldsToUsers \
  address_line1:string \
  address_line2:string \
  postal_code:string \
  city:string \
  country_code:string
```

Edit the generated migration to add default:

```ruby
class AddAddressFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :address_line1, :string
    add_column :users, :address_line2, :string
    add_column :users, :postal_code, :string
    add_column :users, :city, :string
    add_column :users, :country_code, :string, default: 'CH'
  end
end
```

Run: `bin/rails db:migrate`

**Step 4: Add model methods and validations**

Add to `app/models/user.rb`:

```ruby
# Address validation - require all fields if any are present
validates :address_line1, :postal_code, :city, :country_code,
          presence: true,
          if: :any_address_field_present?

def address_complete?
  address_line1.present? && postal_code.present? && city.present? && country_code.present?
end

def full_address_line
  [address_line1, address_line2].compact_blank.join(', ')
end

private

def any_address_field_present?
  address_line1.present? || address_line2.present? || postal_code.present? || city.present?
end
```

**Step 5: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/user_spec.rb -f d`

Expected: All tests PASS

**Step 6: Update user_spec.rb expected_attributes**

Update the `expected_attributes` array in `spec/models/user_spec.rb` to include the new fields:

```ruby
expected_attributes = %w[
  id
  email
  username
  role
  encrypted_password
  remember_created_at
  sign_in_count
  current_sign_in_at
  last_sign_in_at
  current_sign_in_ip
  last_sign_in_ip
  disabled
  first_name
  last_name
  preferred_language
  created_at
  updated_at
  provider
  uid
  billing_type
  cashctrl_person_id
  cashctrl_private_account_id
  prepaid_threshold
  prepaid_topup_amount
  address_line1
  address_line2
  postal_code
  city
  country_code
]
```

**Step 7: Run all user tests**

Run: `bundle exec rspec spec/models/user_spec.rb -f d`

Expected: All tests PASS

**Step 8: Commit**

```bash
git add db/migrate/*_add_address_fields_to_users.rb app/models/user.rb spec/models/user_spec.rb db/schema.rb
git commit -m "feat: add address fields to User model

- Add address_line1, address_line2, postal_code, city, country_code
- Add address_complete? and full_address_line helper methods
- Validate all required fields when any address field is present"
```

---

## Task 2: Add CashCtrl update_person Method

**Files:**
- Modify: `app/services/cashctrl_client.rb`
- Test: `spec/services/cashctrl_client_spec.rb`

**Step 1: Write the failing test**

Add to `spec/services/cashctrl_client_spec.rb`:

```ruby
describe '#update_person' do
  before do
    allow(Rails.application.config).to receive(:cashctrl).and_return({
      org: 'test-org',
      api_key: 'test-key'
    })
  end

  it 'updates person with address' do
    stub_request(:post, 'https://test-org.cashctrl.com/api/v1/person/update.json')
      .to_return(status: 200, body: '{"success": true}')

    user = OpenStruct.new(
      cashctrl_person_id: 123,
      first_name: 'Max',
      last_name: 'Muster',
      full_address_line: 'Musterstrasse 1, Apt 3B',
      postal_code: '4000',
      city: 'Basel',
      country_code: 'CH'
    )

    result = client.update_person(user)
    expect(result['success']).to be true
  end

  it 'sends correct address payload' do
    request_stub = stub_request(:post, 'https://test-org.cashctrl.com/api/v1/person/update.json')
      .with(body: hash_including(
        'id' => '123',
        'firstName' => 'Max',
        'lastName' => 'Muster'
      ))
      .to_return(status: 200, body: '{"success": true}')

    user = OpenStruct.new(
      cashctrl_person_id: 123,
      first_name: 'Max',
      last_name: 'Muster',
      full_address_line: 'Musterstrasse 1',
      postal_code: '4000',
      city: 'Basel',
      country_code: 'CH'
    )

    client.update_person(user)
    expect(request_stub).to have_been_requested
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/services/cashctrl_client_spec.rb:225 -f d`

Expected: FAIL with "undefined method `update_person'"

**Step 3: Implement update_person method**

Add to `app/services/cashctrl_client.rb` after `find_or_create_person`:

```ruby
def update_person(user)
  address_data = {
    type: 'MAIN',
    address: user.full_address_line.presence,
    zip: user.postal_code,
    city: user.city,
    country: user.country_code
  }.compact

  post('/person/update.json', {
    id: user.cashctrl_person_id,
    firstName: user.first_name,
    lastName: user.last_name,
    addresses: [address_data].to_json
  })
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/services/cashctrl_client_spec.rb -f d`

Expected: All tests PASS

**Step 5: Commit**

```bash
git add app/services/cashctrl_client.rb spec/services/cashctrl_client_spec.rb
git commit -m "feat: add update_person method to CashctrlClient

Syncs user name and address to CashCtrl person record"
```

---

## Task 3: Create ProfileController

**Files:**
- Create: `app/controllers/profile_controller.rb`
- Create: `spec/requests/profile_spec.rb`
- Modify: `config/routes.rb`

**Step 1: Write the failing tests**

Create `spec/requests/profile_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Profile', type: :request do
  let(:user) do
    User.create!(
      username: 'testuser',
      email: 'test@example.com',
      first_name: 'Test',
      last_name: 'User'
    )
  end

  describe 'GET /profile' do
    context 'when not authenticated' do
      it 'redirects to login' do
        get profile_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when authenticated' do
      before { sign_in user }

      it 'returns success' do
        get profile_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'GET /profile/edit' do
    context 'when authenticated' do
      before { sign_in user }

      it 'returns success' do
        get edit_profile_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'PATCH /profile' do
    before { sign_in user }

    it 'updates user profile' do
      patch profile_path, params: {
        user: {
          first_name: 'Updated',
          last_name: 'Name',
          address_line1: 'Musterstrasse 1',
          postal_code: '4000',
          city: 'Basel',
          country_code: 'CH'
        }
      }

      expect(response).to redirect_to(profile_path)
      user.reload
      expect(user.first_name).to eq('Updated')
      expect(user.address_line1).to eq('Musterstrasse 1')
    end

    it 'does not allow updating email' do
      original_email = user.email
      patch profile_path, params: {
        user: { email: 'hacker@evil.com' }
      }

      user.reload
      expect(user.email).to eq(original_email)
    end

    context 'with invalid params' do
      it 'renders edit with errors' do
        patch profile_path, params: {
          user: {
            address_line1: 'Partial address only'
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/requests/profile_spec.rb -f d`

Expected: FAIL with "undefined method `profile_path'"

**Step 3: Add route**

Add to `config/routes.rb` after the `root` line:

```ruby
resource :profile, only: [:show, :edit, :update], controller: 'profile'
```

**Step 4: Run tests again**

Run: `bundle exec rspec spec/requests/profile_spec.rb -f d`

Expected: FAIL with "uninitialized constant ProfileController"

**Step 5: Create controller**

Create `app/controllers/profile_controller.rb`:

```ruby
# frozen_string_literal: true

class ProfileController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
  end

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    if @user.update(profile_params)
      sync_to_cashctrl(@user)
      redirect_to profile_path, notice: t('.success')
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:user).permit(
      :first_name, :last_name, :preferred_language,
      :address_line1, :address_line2, :postal_code, :city, :country_code
    )
  end

  def sync_to_cashctrl(user)
    return unless user.cashctrl_person_id.present?

    CashctrlClient.new.update_person(user)
  rescue StandardError => e
    Rails.logger.error("CashCtrl sync failed: #{e.message}")
    flash[:warning] = t('.cashctrl_sync_failed')
  end
end
```

**Step 6: Run tests again**

Run: `bundle exec rspec spec/requests/profile_spec.rb -f d`

Expected: FAIL with "Missing template profile/show"

**Step 7: Create minimal views (placeholders)**

Create `app/views/profile/show.html.erb`:

```erb
<h1>Profile</h1>
<p><%= @user.first_name %> <%= @user.last_name %></p>
<%= link_to 'Edit', edit_profile_path %>
```

Create `app/views/profile/edit.html.erb`:

```erb
<h1>Edit Profile</h1>
<%= form_with model: @user, url: profile_path, method: :patch do |f| %>
  <%= f.text_field :first_name %>
  <%= f.text_field :last_name %>
  <%= f.text_field :address_line1 %>
  <%= f.text_field :address_line2 %>
  <%= f.text_field :postal_code %>
  <%= f.text_field :city %>
  <%= f.text_field :country_code %>
  <%= f.submit 'Save' %>
<% end %>
```

**Step 8: Add I18n translations**

Add to `config/locales/en.yml` (create profile section):

```yaml
en:
  profile:
    update:
      success: "Profile updated successfully."
      cashctrl_sync_failed: "Profile saved, but billing system sync failed."
```

**Step 9: Run tests to verify they pass**

Run: `bundle exec rspec spec/requests/profile_spec.rb -f d`

Expected: All tests PASS

**Step 10: Commit**

```bash
git add app/controllers/profile_controller.rb spec/requests/profile_spec.rb config/routes.rb app/views/profile/ config/locales/en.yml
git commit -m "feat: add ProfileController with show/edit/update actions

- Add /profile routes
- Sync to CashCtrl on profile update
- Permit address fields in strong params"
```

---

## Task 4: Add CashCtrl Sync Test for ProfileController

**Files:**
- Modify: `spec/requests/profile_spec.rb`

**Step 1: Write the failing test**

Add to `spec/requests/profile_spec.rb`:

```ruby
describe 'PATCH /profile' do
  # ... existing tests ...

  context 'CashCtrl sync' do
    let(:user_with_cashctrl) do
      User.create!(
        username: 'cashctrluser',
        email: 'cashctrl@example.com',
        first_name: 'Cash',
        last_name: 'Ctrl',
        cashctrl_person_id: 123
      )
    end

    before do
      sign_in user_with_cashctrl
      allow(Rails.application.config).to receive(:cashctrl).and_return({
        org: 'test-org',
        api_key: 'test-key'
      })
    end

    it 'syncs to CashCtrl when user has cashctrl_person_id' do
      stub = stub_request(:post, 'https://test-org.cashctrl.com/api/v1/person/update.json')
        .to_return(status: 200, body: '{"success": true}')

      patch profile_path, params: {
        user: {
          address_line1: 'Musterstrasse 1',
          postal_code: '4000',
          city: 'Basel',
          country_code: 'CH'
        }
      }

      expect(stub).to have_been_requested
    end

    it 'does not fail when CashCtrl sync fails' do
      stub_request(:post, 'https://test-org.cashctrl.com/api/v1/person/update.json')
        .to_return(status: 500, body: '{"error": "Server error"}')

      patch profile_path, params: {
        user: { first_name: 'Updated' }
      }

      expect(response).to redirect_to(profile_path)
      user_with_cashctrl.reload
      expect(user_with_cashctrl.first_name).to eq('Updated')
    end
  end
end
```

**Step 2: Run tests to verify they pass**

Run: `bundle exec rspec spec/requests/profile_spec.rb -f d`

Expected: All tests PASS (sync is already implemented)

**Step 3: Commit**

```bash
git add spec/requests/profile_spec.rb
git commit -m "test: add CashCtrl sync tests for profile updates"
```

---

## Task 5: Create Styled Profile Views

**Files:**
- Modify: `app/views/profile/show.html.erb`
- Modify: `app/views/profile/edit.html.erb`
- Create: `app/helpers/profile_helper.rb`

**Step 1: Create profile helper**

Create `app/helpers/profile_helper.rb`:

```ruby
# frozen_string_literal: true

module ProfileHelper
  def country_options_for_select
    [
      ['Switzerland', 'CH'],
      ['Germany', 'DE'],
      ['France', 'FR'],
      ['Austria', 'AT'],
      ['Italy', 'IT'],
      ['Liechtenstein', 'LI']
    ]
  end
end
```

**Step 2: Update show view with Spectrum styling**

Replace `app/views/profile/show.html.erb`:

```erb
<% content_for :title, t('.title') %>

<header class="spectrum-CSSComponent-sectionHeading">
  <h2 class="spectrum-Heading spectrum-Heading--sizeM"><%= t('.title') %></h2>
  <hr class="spectrum-Divider spectrum-Divider--large">
</header>

<section class="spectrum-CSSComponent-description">
  <div class="spectrum-Body spectrum-Body--sizeM">
    <dl class="spectrum-Table spectrum-Table--sizeM">
      <div class="spectrum-Table-row">
        <dt class="spectrum-Table-headCell"><%= User.human_attribute_name(:name) %></dt>
        <dd class="spectrum-Table-cell"><%= @user.first_name %> <%= @user.last_name %></dd>
      </div>

      <div class="spectrum-Table-row">
        <dt class="spectrum-Table-headCell"><%= User.human_attribute_name(:email) %></dt>
        <dd class="spectrum-Table-cell"><%= @user.email %></dd>
      </div>

      <div class="spectrum-Table-row">
        <dt class="spectrum-Table-headCell"><%= t('.address') %></dt>
        <dd class="spectrum-Table-cell">
          <% if @user.address_complete? %>
            <%= @user.address_line1 %><br>
            <% if @user.address_line2.present? %>
              <%= @user.address_line2 %><br>
            <% end %>
            <%= @user.postal_code %> <%= @user.city %><br>
            <%= @user.country_code %>
          <% else %>
            <em class="spectrum-Body--secondary"><%= t('.no_address') %></em>
          <% end %>
        </dd>
      </div>
    </dl>

    <%= link_to t('.edit'), edit_profile_path,
        class: 'spectrum-Button spectrum-Button--fill spectrum-Button--accent spectrum-Button--sizeM' %>
  </div>
</section>
```

**Step 3: Update edit view with Spectrum styling**

Replace `app/views/profile/edit.html.erb`:

```erb
<% content_for :title, t('.title') %>

<header class="spectrum-CSSComponent-sectionHeading">
  <h2 class="spectrum-Heading spectrum-Heading--sizeM"><%= t('.title') %></h2>
  <hr class="spectrum-Divider spectrum-Divider--large">
</header>

<section class="spectrum-CSSComponent-description">
  <%= form_with model: @user, url: profile_path, method: :patch, class: 'spectrum-Form' do |f| %>
    <% if @user.errors.any? %>
      <div class="spectrum-Toast spectrum-Toast--negative">
        <div class="spectrum-Toast-body">
          <div class="spectrum-Toast-content">
            <ul>
              <% @user.errors.full_messages.each do |message| %>
                <li><%= message %></li>
              <% end %>
            </ul>
          </div>
        </div>
      </div>
    <% end %>

    <div class="spectrum-Form-item">
      <%= f.label :first_name, class: 'spectrum-FieldLabel spectrum-FieldLabel--sizeM' %>
      <%= f.text_field :first_name, class: 'spectrum-Textfield-input', required: true %>
    </div>

    <div class="spectrum-Form-item">
      <%= f.label :last_name, class: 'spectrum-FieldLabel spectrum-FieldLabel--sizeM' %>
      <%= f.text_field :last_name, class: 'spectrum-Textfield-input', required: true %>
    </div>

    <fieldset class="spectrum-Fieldset">
      <legend class="spectrum-Fieldset-legend"><%= t('.address_section') %></legend>

      <div class="spectrum-Form-item">
        <%= f.label :address_line1, t('.address_line1'), class: 'spectrum-FieldLabel spectrum-FieldLabel--sizeM' %>
        <%= f.text_field :address_line1, class: 'spectrum-Textfield-input',
            placeholder: t('.address_line1_placeholder') %>
      </div>

      <div class="spectrum-Form-item">
        <%= f.label :address_line2, t('.address_line2'), class: 'spectrum-FieldLabel spectrum-FieldLabel--sizeM' %>
        <%= f.text_field :address_line2, class: 'spectrum-Textfield-input',
            placeholder: t('.address_line2_placeholder') %>
      </div>

      <div class="spectrum-Form-item">
        <%= f.label :postal_code, class: 'spectrum-FieldLabel spectrum-FieldLabel--sizeM' %>
        <%= f.text_field :postal_code, class: 'spectrum-Textfield-input' %>
      </div>

      <div class="spectrum-Form-item">
        <%= f.label :city, class: 'spectrum-FieldLabel spectrum-FieldLabel--sizeM' %>
        <%= f.text_field :city, class: 'spectrum-Textfield-input' %>
      </div>

      <div class="spectrum-Form-item">
        <%= f.label :country_code, class: 'spectrum-FieldLabel spectrum-FieldLabel--sizeM' %>
        <%= f.select :country_code, country_options_for_select,
            {}, class: 'spectrum-Picker-input' %>
      </div>
    </fieldset>

    <div class="spectrum-ButtonGroup">
      <%= f.submit t('.save'), class: 'spectrum-Button spectrum-Button--fill spectrum-Button--accent spectrum-Button--sizeM' %>
      <%= link_to t('.cancel'), profile_path, class: 'spectrum-Button spectrum-Button--secondary spectrum-Button--sizeM' %>
    </div>
  <% end %>
</section>
```

**Step 4: Add I18n translations**

Update `config/locales/en.yml`:

```yaml
en:
  profile:
    show:
      title: "My Profile"
      address: "Address"
      no_address: "No address provided"
      edit: "Edit Profile"
    edit:
      title: "Edit Profile"
      address_section: "Billing Address"
      address_line1: "Street and number"
      address_line1_placeholder: "e.g. Musterstrasse 1"
      address_line2: "Additional info"
      address_line2_placeholder: "Apartment, c/o, etc. (optional)"
      save: "Save"
      cancel: "Cancel"
    update:
      success: "Profile updated successfully."
      cashctrl_sync_failed: "Profile saved, but billing system sync failed."
```

Add `config/locales/de.yml`:

```yaml
de:
  profile:
    show:
      title: "Mein Profil"
      address: "Adresse"
      no_address: "Keine Adresse angegeben"
      edit: "Profil bearbeiten"
    edit:
      title: "Profil bearbeiten"
      address_section: "Rechnungsadresse"
      address_line1: "Strasse und Hausnummer"
      address_line1_placeholder: "z.B. Musterstrasse 1"
      address_line2: "Zusatzangaben"
      address_line2_placeholder: "Wohnung, c/o, etc. (optional)"
      save: "Speichern"
      cancel: "Abbrechen"
    update:
      success: "Profil erfolgreich aktualisiert."
      cashctrl_sync_failed: "Profil gespeichert, aber Synchronisierung mit Buchhaltung fehlgeschlagen."
```

**Step 5: Run tests to verify views work**

Run: `bundle exec rspec spec/requests/profile_spec.rb -f d`

Expected: All tests PASS

**Step 6: Commit**

```bash
git add app/views/profile/ app/helpers/profile_helper.rb config/locales/
git commit -m "feat: add styled profile views with Spectrum CSS

- Show page displays user info and address
- Edit form with fieldset for address fields
- German and English translations"
```

---

## Task 6: Add Profile Reminder Banner to Dashboard

**Files:**
- Create: `app/views/dashboard/_profile_reminder.html.erb`
- Modify: `app/views/dashboard/welcome.html.erb`

**Step 1: Create reminder partial**

Create `app/views/dashboard/_profile_reminder.html.erb`:

```erb
<% unless current_user.address_complete? %>
  <div class="spectrum-Toast spectrum-Toast--info" style="margin-bottom: 1rem; display: flex;">
    <div class="spectrum-Toast-body">
      <div class="spectrum-Toast-content">
        <%= t('profile.incomplete_address_warning') %>
        <%= link_to t('profile.complete_profile'), edit_profile_path, class: 'spectrum-Link' %>
      </div>
    </div>
  </div>
<% end %>
```

**Step 2: Add partial to dashboard**

Add at the top of `app/views/dashboard/welcome.html.erb` (after line 3):

```erb
<%= render 'dashboard/profile_reminder' %>
```

**Step 3: Add I18n keys**

Add to `config/locales/en.yml` under profile:

```yaml
en:
  profile:
    incomplete_address_warning: "Please complete your billing address for invoices."
    complete_profile: "Complete profile →"
```

Add to `config/locales/de.yml` under profile:

```yaml
de:
  profile:
    incomplete_address_warning: "Bitte vervollständigen Sie Ihre Rechnungsadresse."
    complete_profile: "Profil vervollständigen →"
```

**Step 4: Verify manually (no automated test needed)**

Start server and check dashboard shows banner when logged in as user without address.

**Step 5: Commit**

```bash
git add app/views/dashboard/ config/locales/
git commit -m "feat: add profile reminder banner to dashboard

Shows when user has no billing address"
```

---

## Task 7: Add Profile Badge to Navigation

**Files:**
- Modify: `app/views/layouts/_navigation.html.erb`

**Step 1: Update navigation with profile link and badge**

In `app/views/layouts/_navigation.html.erb`, replace the Profile section (lines 12-34) with:

```erb
<li class="spectrum-SideNav-item">
  <a class="spectrum-SideNav-itemLink js-fastLoad" href="<%= profile_path %>">
    <svg class="spectrum-Icon spectrum-Icon--sizeM spectrum-SideNav-itemIcon" focusable="false" aria-hidden="true">
      <use xlink:href="#spectrum-icon-18-RealTimeCustomerProfile"/>
    </svg>
    <%= t('nav.profile') %>
    <% unless current_user.address_complete? %>
      <span class="spectrum-Badge spectrum-Badge--sizeS spectrum-Badge--yellow" style="margin-left: auto;">!</span>
    <% end %>
  </a>
  <ul class="spectrum-SideNav spectrum-SideNav--multiLevel">
    <li class="spectrum-SideNav-item">
      <a class="spectrum-SideNav-itemLink js-fastLoad" href="<%= user_vehicles_path(current_user.id) %>">
        <svg class="spectrum-Icon spectrum-Icon--sizeM spectrum-SideNav-itemIcon" focusable="false" aria-hidden="true">
          <use xlink:href="#spectrum-icon-18-Car"/>
        </svg>
        <%= t('nav.my_vehicles') %>
      </a>
      <a class="spectrum-SideNav-itemLink js-fastLoad" href="<%= user_billing_path(current_user.id) %>">
        <svg class="spectrum-Icon spectrum-Icon--sizeM spectrum-SideNav-itemIcon" focusable="false" aria-hidden="true">
          <use xlink:href="#spectrum-icon-18-Money"/>
        </svg>
        <%= t('nav.my_billing') %>
      </a>
    </li>
  </ul>
</li>
```

**Step 2: Add I18n keys for navigation**

Add to `config/locales/en.yml`:

```yaml
en:
  nav:
    profile: "Profile"
    my_vehicles: "My Vehicles"
    my_billing: "My Billing"
```

Add to `config/locales/de.yml`:

```yaml
de:
  nav:
    profile: "Profil"
    my_vehicles: "Meine Fahrzeuge"
    my_billing: "Meine Rechnungen"
```

**Step 3: Commit**

```bash
git add app/views/layouts/_navigation.html.erb config/locales/
git commit -m "feat: add profile link with badge to navigation

Shows warning badge when address is incomplete"
```

---

## Task 8: Update find_or_create_person to Sync Address

**Files:**
- Modify: `app/services/cashctrl_client.rb`
- Modify: `spec/services/cashctrl_client_spec.rb`

**Step 1: Write failing test**

Add to `spec/services/cashctrl_client_spec.rb`:

```ruby
describe '#find_or_create_person with address' do
  before do
    allow(Rails.application.config).to receive(:cashctrl).and_return({
      org: 'test-org',
      api_key: 'test-key'
    })
  end

  it 'includes address when creating new person' do
    stub_request(:get, 'https://test-org.cashctrl.com/api/v1/person/list.json')
      .with(query: { query: 'new@example.com' })
      .to_return(status: 200, body: '{"data": []}')

    create_stub = stub_request(:post, 'https://test-org.cashctrl.com/api/v1/person/create.json')
      .to_return(status: 200, body: '{"success": true, "insertId": 999}')

    user = OpenStruct.new(
      email: 'new@example.com',
      first_name: 'New',
      last_name: 'User',
      full_address_line: 'Teststrasse 1',
      postal_code: '8000',
      city: 'Zurich',
      country_code: 'CH',
      address_complete?: true
    )

    result = client.find_or_create_person(user)
    expect(result).to eq(999)
    expect(create_stub).to have_been_requested
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/services/cashctrl_client_spec.rb -f d`

Expected: May pass or fail depending on current implementation

**Step 3: Update find_or_create_person**

Update the method in `app/services/cashctrl_client.rb`:

```ruby
def find_or_create_person(user)
  person = find_person_by_email(user.email)
  if person
    # Store the cashctrl_person_id if not already stored
    person['id']
  else
    create_person(
      first_name: user.first_name,
      last_name: user.last_name,
      email: user.email,
      address: user.respond_to?(:full_address_line) ? user.full_address_line : nil,
      zip: user.respond_to?(:postal_code) ? user.postal_code : nil,
      city: user.respond_to?(:city) ? user.city : nil,
      country: user.respond_to?(:country_code) ? user.country_code : nil
    )
  end
end
```

**Step 4: Run tests**

Run: `bundle exec rspec spec/services/cashctrl_client_spec.rb -f d`

Expected: All tests PASS

**Step 5: Commit**

```bash
git add app/services/cashctrl_client.rb spec/services/cashctrl_client_spec.rb
git commit -m "feat: include address when creating CashCtrl person

Address is included if user has address fields"
```

---

## Task 9: Final Integration Test

**Files:**
- Test: `spec/requests/profile_spec.rb`

**Step 1: Add integration test**

Add to `spec/requests/profile_spec.rb`:

```ruby
describe 'full profile flow' do
  let(:user) do
    User.create!(
      username: 'flowuser',
      email: 'flow@example.com',
      first_name: 'Flow',
      last_name: 'User'
    )
  end

  before { sign_in user }

  it 'allows user to complete their profile' do
    # Initially no address
    expect(user.address_complete?).to be false

    # Visit profile
    get profile_path
    expect(response.body).to include('No address provided')

    # Edit profile
    get edit_profile_path
    expect(response).to have_http_status(:success)

    # Submit address
    patch profile_path, params: {
      user: {
        address_line1: 'Bahnhofstrasse 10',
        postal_code: '8001',
        city: 'Zürich',
        country_code: 'CH'
      }
    }

    expect(response).to redirect_to(profile_path)

    # Verify saved
    user.reload
    expect(user.address_complete?).to be true
    expect(user.full_address_line).to eq('Bahnhofstrasse 10')

    # Profile shows address
    get profile_path
    expect(response.body).to include('Bahnhofstrasse 10')
    expect(response.body).to include('8001')
    expect(response.body).to include('Zürich')
  end
end
```

**Step 2: Run all tests**

Run: `bundle exec rspec spec/requests/profile_spec.rb spec/models/user_spec.rb spec/services/cashctrl_client_spec.rb -f d`

Expected: All tests PASS

**Step 3: Final commit**

```bash
git add spec/requests/profile_spec.rb
git commit -m "test: add full profile flow integration test"
```

---

## Task 10: Run Full Test Suite and Cleanup

**Step 1: Run full test suite**

Run: `bundle exec rspec --format progress`

Expected: All tests PASS

**Step 2: Run linter**

Run: `bundle exec rubocop -a`

Fix any issues.

**Step 3: Final commit if needed**

```bash
git add -A
git commit -m "chore: fix rubocop violations" --allow-empty
```

**Step 4: Summary commit/tag**

```bash
git log --oneline -10
```

---

## Summary

After completing all tasks, you will have:

1. ✅ Address fields on User model with validation
2. ✅ `address_complete?` and `full_address_line` helpers
3. ✅ ProfileController with show/edit/update
4. ✅ CashCtrl sync on profile save
5. ✅ Styled profile views with Spectrum CSS
6. ✅ Dashboard reminder banner
7. ✅ Navigation badge for incomplete profiles
8. ✅ Full test coverage
