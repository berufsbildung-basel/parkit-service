# frozen_string_literal: true

module Users
  # Okta Callback controller
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    skip_before_action :verify_authenticity_token, only: :okta

    def okta
      @user = User.from_omniauth(request.env['omniauth.auth'])

      if @user.save
        sign_in_and_redirect @user, event: :authentication # this will throw if @user is not activated
        set_flash_message(:notice, :success, kind: 'Okta') if is_navigational_format?
      else
        print(@user.errors.full_messages)
      end
    end

    def failure
      redirect_to root_path
    end
  end
end
