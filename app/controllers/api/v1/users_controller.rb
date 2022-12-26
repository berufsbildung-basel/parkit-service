# frozen_string_literal: true

module Api
  module V1
    # Actions for the user resource
    class UsersController < ApiController
      def create
        # Users are created upon login from Single Sign On (Okta) and may not be created manually
        raise NotImplementedError
      end

      def disable
        @user = User.find(params[:user_id])
        @user.disabled = true
        @user.save!
      end

      def enable
        @user = User.find(params[:user_id])
        @user.disabled = false
        @user.save!
      end

      def index
        @users = User.all.page(page_params[:page]).per(page_params[:page_size])
      end

      def show
        @user = User.find(params[:id])
      end

      def update
        @user = User.find(params[:id])

        @user.update!(user_params)

        render @user
      end

      def user_params
        params.permit(
          :preferred_language
        )
      end
    end
  end
end
