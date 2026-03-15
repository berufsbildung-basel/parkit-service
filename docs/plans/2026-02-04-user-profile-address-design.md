# User Profile & Address Management Design

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow users to manage their profile and address for Swiss QR-bill invoicing.

**Architecture:** Rails stores address as source of truth, syncs one-way to CashCtrl on profile save. Users without addresses see reminders but are not blocked.

**Tech Stack:** Rails 7.1, CashCtrl API, Devise authentication

---

## Decisions Made

| Topic | Decision |
|-------|----------|
| Storage | Rails as primary, sync to CashCtrl |
| Address fields | International standard (line1, line2, postal_code, city, country_code) |
| UI location | New `/profile` route |
| Missing address handling | Leave blank, show reminder |
| Reminder style | Dashboard banner + nav badge |
| Sync timing | Immediate on profile save |

---

## Data Model

### Migration

```ruby
# db/migrate/XXXXXX_add_address_fields_to_users.rb
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

### User Model

```ruby
# app/models/user.rb (additions)

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

---

## Routes

```ruby
# config/routes.rb (addition)
resource :profile, only: [:show, :edit, :update], controller: 'profile'
```

Routes:
- `GET /profile` → view profile
- `GET /profile/edit` → edit form
- `PATCH /profile` → save changes

---

## Controller

```ruby
# app/controllers/profile_controller.rb
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

---

## CashCtrl Sync

### New method: `update_person`

```ruby
# app/services/cashctrl_client.rb (addition)

def update_person(user)
  address_data = {
    type: 'MAIN',
    address: user.full_address_line,
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

### Update `find_or_create_person`

```ruby
def find_or_create_person(user)
  person = find_person_by_email(user.email)
  if person
    update_person(user) if user.address_complete? && user.cashctrl_person_id.present?
    person['id']
  else
    create_person(
      first_name: user.first_name,
      last_name: user.last_name,
      email: user.email,
      address: user.full_address_line,
      zip: user.postal_code,
      city: user.city,
      country: user.country_code
    )
  end
end
```

---

## Views

### Profile Show

```erb
<%# app/views/profile/show.html.erb %>
<h1><%= t('.title') %></h1>

<dl>
  <dt><%= User.human_attribute_name(:name) %></dt>
  <dd><%= @user.first_name %> <%= @user.last_name %></dd>

  <dt><%= User.human_attribute_name(:email) %></dt>
  <dd><%= @user.email %></dd>

  <dt><%= User.human_attribute_name(:address) %></dt>
  <dd>
    <% if @user.address_complete? %>
      <%= @user.address_line1 %><br>
      <% if @user.address_line2.present? %><%= @user.address_line2 %><br><% end %>
      <%= @user.postal_code %> <%= @user.city %><br>
      <%= @user.country_code %>
    <% else %>
      <em><%= t('.no_address') %></em>
    <% end %>
  </dd>
</dl>

<%= link_to t('.edit'), edit_profile_path, class: 'btn btn-primary' %>
```

### Profile Edit

```erb
<%# app/views/profile/edit.html.erb %>
<h1><%= t('.title') %></h1>

<%= form_with model: @user, url: profile_path, method: :patch do |f| %>
  <%= f.text_field :first_name %>
  <%= f.text_field :last_name %>

  <fieldset>
    <legend><%= t('.address_section') %></legend>
    <%= f.text_field :address_line1, placeholder: t('.address_line1_placeholder') %>
    <%= f.text_field :address_line2, placeholder: t('.address_line2_placeholder') %>
    <%= f.text_field :postal_code %>
    <%= f.text_field :city %>
    <%= f.select :country_code, country_options, include_blank: false %>
  </fieldset>

  <%= f.submit t('.save') %>
<% end %>
```

---

## Reminder UI

### Dashboard Banner

```erb
<%# app/views/dashboard/_profile_reminder.html.erb %>
<% unless current_user.address_complete? %>
  <div class="alert alert-info" role="alert">
    <%= t('profile.incomplete_address_warning') %>
    <%= link_to t('profile.complete_profile'), edit_profile_path, class: 'alert-link' %>
  </div>
<% end %>
```

### Navigation Badge

```erb
<%# In navigation partial %>
<%= link_to profile_path, class: 'nav-link' do %>
  <%= t('nav.profile') %>
  <% unless current_user.address_complete? %>
    <span class="badge badge-warning">!</span>
  <% end %>
<% end %>
```

---

## I18n

```yaml
# config/locales/en.yml
en:
  profile:
    show:
      title: "My Profile"
      no_address: "No address provided"
      edit: "Edit Profile"
    edit:
      title: "Edit Profile"
      address_section: "Address"
      address_line1_placeholder: "Street and number"
      address_line2_placeholder: "Apartment, c/o, etc. (optional)"
      save: "Save"
    update:
      success: "Profile updated successfully."
      cashctrl_sync_failed: "Profile saved, but billing system sync failed. Please try again later."
    incomplete_address_warning: "Please complete your address for billing purposes."
    complete_profile: "Complete profile"
  nav:
    profile: "Profile"

# config/locales/de.yml
de:
  profile:
    show:
      title: "Mein Profil"
      no_address: "Keine Adresse angegeben"
      edit: "Profil bearbeiten"
    edit:
      title: "Profil bearbeiten"
      address_section: "Adresse"
      address_line1_placeholder: "Strasse und Hausnummer"
      address_line2_placeholder: "Wohnung, c/o, etc. (optional)"
      save: "Speichern"
    update:
      success: "Profil erfolgreich aktualisiert."
      cashctrl_sync_failed: "Profil gespeichert, aber Synchronisierung mit Buchhaltung fehlgeschlagen."
    incomplete_address_warning: "Bitte vervollständigen Sie Ihre Adresse für die Rechnungsstellung."
    complete_profile: "Profil vervollständigen"
  nav:
    profile: "Profil"
```

---

## Testing

### Model specs
- `User#address_complete?` returns true/false correctly
- `User#full_address_line` concatenates line1 + line2
- Validation: partial address is invalid

### Controller specs
- `GET /profile` requires authentication
- `PATCH /profile` updates user and syncs to CashCtrl
- CashCtrl failure doesn't block profile save

### Service specs
- `CashctrlClient#update_person` sends correct payload
- `find_or_create_person` updates address when changed

---

## Out of Scope

- Email notifications for incomplete profiles
- Address autocomplete
- Multiple addresses per user
- TWINT alternative procedures (CashCtrl limitation)
