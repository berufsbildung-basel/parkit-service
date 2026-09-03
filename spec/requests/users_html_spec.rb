# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'UsersController (HTML)', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) do
    User.create!(username: 'admin-user', email: 'admin-user@example.com', first_name: 'Admin', last_name: 'User',
                 role: :admin)
  end
  let!(:target_user) do
    User.create!(username: 'target-user', email: 'target-user@example.com', first_name: 'Target', last_name: 'User')
  end

  before { sign_in admin }

  describe 'GET /users/:id/edit' do
    it 'offers facilities as a role option' do
      get edit_user_path(target_user.id)

      expect(response).to have_http_status(200)
      expect(response.body).to match(/<option[^>]*>facilities<\/option>/)
    end
  end

  describe 'PUT /users/:id' do
    it 'promotes a user to facilities' do
      put user_path(target_user.id), params: { user: { role: 'facilities' } }

      expect(response).to redirect_to(user_path(target_user.id))
      expect(target_user.reload.role).to eq('facilities')
    end
  end
end
