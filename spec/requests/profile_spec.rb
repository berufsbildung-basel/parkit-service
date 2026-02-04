# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Profile', type: :request do
  include Devise::Test::IntegrationHelpers

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

  describe 'full profile flow' do
    let(:flow_user) do
      User.create!(
        username: 'flowuser',
        email: 'flow@example.com',
        first_name: 'Flow',
        last_name: 'User'
      )
    end

    before { sign_in flow_user }

    it 'allows user to complete their profile' do
      # Initially no address
      expect(flow_user.address_complete?).to be false

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
      flow_user.reload
      expect(flow_user.address_complete?).to be true
      expect(flow_user.full_address_line).to eq('Bahnhofstrasse 10')

      # Profile shows address
      get profile_path
      expect(response.body).to include('Bahnhofstrasse 10')
      expect(response.body).to include('8001')
      expect(response.body).to include('Zürich')
    end
  end
end
