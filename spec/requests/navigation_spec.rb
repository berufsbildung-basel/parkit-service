# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Navigation', type: :request do
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

  describe 'GET /dashboard' do
    it 'shows the Administration section to admin' do
      sign_in admin
      get dashboard_path

      expect(response.body).to include('Administration')
    end

    it 'shows the Administration section to facilities' do
      sign_in facilities_user
      get dashboard_path

      expect(response.body).to include('Administration')
    end

    it 'hides the Administration section from a regular user' do
      sign_in regular_user
      get dashboard_path

      expect(response.body).not_to include('Administration')
    end
  end
end
