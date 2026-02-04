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
  end
end
