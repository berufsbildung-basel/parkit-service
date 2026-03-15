# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserBillingController, type: :controller do
  render_views

  include Devise::Test::ControllerHelpers

  let(:user) do
    User.create!(
      username: 'billinguser',
      email: 'billing@example.com',
      first_name: 'Billing',
      last_name: 'User'
    )
  end

  let(:other_user) do
    User.create!(
      username: 'otheruser',
      email: 'other@example.com',
      first_name: 'Other',
      last_name: 'User'
    )
  end

  before { sign_in user }

  describe 'GET #index' do
    let!(:invoice) do
      Invoice.create!(
        user: user,
        period_start: Date.new(2026, 1, 1),
        period_end: Date.new(2026, 1, 31),
        total_amount: 120.0,
        status: :sent,
        cashctrl_person_id: 1
      )
    end

    let!(:other_invoice) do
      Invoice.create!(
        user: other_user,
        period_start: Date.new(2026, 1, 1),
        period_end: Date.new(2026, 1, 31),
        total_amount: 80.0,
        cashctrl_person_id: 2
      )
    end

    it 'assigns invoices for the requested user' do
      get :index, params: { user_id: user.id }
      expect(assigns(:invoices)).to include(invoice)
      expect(assigns(:invoices)).not_to include(other_invoice)
    end
  end
end
