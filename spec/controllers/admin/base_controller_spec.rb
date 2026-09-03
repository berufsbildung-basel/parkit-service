# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::BaseController access', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) do
    User.create!(username: 'admin-user', email: 'admin@example.com', first_name: 'Admin', last_name: 'User',
                 role: :admin)
  end
  let(:facilities_user) do
    User.create!(username: 'facilities-user', email: 'facilities@example.com', first_name: 'Facilities',
                 last_name: 'User', role: :facilities)
  end
  let(:regular_user) do
    User.create!(username: 'regular-user', email: 'user@example.com', first_name: 'Regular', last_name: 'User')
  end

  before { allow_any_instance_of(CashctrlClient).to receive(:ping).and_return(true) }

  describe 'GET /admin/billing' do
    it 'permits admin' do
      sign_in admin
      get admin_billing_path

      expect(response).to have_http_status(200)
    end

    it 'permits facilities' do
      sign_in facilities_user
      get admin_billing_path

      expect(response).to have_http_status(200)
    end

    it 'forbids a regular user' do
      sign_in regular_user
      get admin_billing_path

      expect(response).to redirect_to(root_path)
    end
  end
end
