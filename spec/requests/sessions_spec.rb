# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sessions', type: :request do
  describe 'GET /users/sign_in' do
    it 'returns success' do
      get new_user_session_path

      expect(response).to have_http_status(:success)
    end

    # Regression: cached/back-restored login forms carry a stale CSRF token that
    # no longer matches the current session cookie, producing a 422
    # (ActionController::InvalidAuthenticityToken) on the Okta login POST.
    # no-store keeps the form (and its token) out of the HTTP cache and bfcache.
    it 'sets Cache-Control: no-store to prevent stale CSRF tokens in cached forms' do
      get new_user_session_path

      expect(response.headers['Cache-Control']).to include('no-store')
    end
  end
end
