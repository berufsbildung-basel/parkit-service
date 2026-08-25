# frozen_string_literal: true

module Users
  # Custom Devise sessions controller.
  #
  # The login form embeds a CSRF authenticity_token that is only valid together
  # with the current session cookie. If a browser serves this page from its HTTP
  # cache or its back/forward cache (bfcache), the stale token no longer matches
  # the session and the Okta login POST fails with
  # ActionController::InvalidAuthenticityToken - the 422 "The change you wanted
  # was rejected" page. Sending Cache-Control: no-store keeps the form (and its
  # token) out of both caches, so every visit renders a fresh, matching token.
  class SessionsController < Devise::SessionsController
    before_action :set_no_store, only: :new

    private

    def set_no_store
      response.headers['Cache-Control'] = 'no-store'
    end
  end
end
