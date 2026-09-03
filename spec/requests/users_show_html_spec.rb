# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'UsersController#show (HTML)', type: :request do
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
  let!(:prepaid_user) do
    User.create!(username: 'prepaid-user', email: 'prepaid@example.com', first_name: 'Prepaid', last_name: 'User',
                 billing_type: :prepaid, cashctrl_private_account_id: 42)
  end

  before { allow_any_instance_of(CashctrlClient).to receive(:get_account_balance).and_return(100.0) }

  describe 'GET /users/:id' do
    it 'shows the prepaid account section to admin' do
      sign_in admin
      get user_path(prepaid_user.id)

      expect(response.body).to include('Prepaid Account')
    end

    it 'shows the prepaid account section to facilities' do
      sign_in facilities_user
      get user_path(prepaid_user.id)

      expect(response.body).to include('Prepaid Account')
    end

    it 'hides the prepaid account section from a regular (non-managing) user viewing their own prepaid profile' do
      sign_in prepaid_user
      get user_path(prepaid_user.id)

      expect(response.body).not_to include('Prepaid Account')
    end
  end
end
