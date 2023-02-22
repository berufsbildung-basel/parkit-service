# frozen_string_literal: true

module Api
  module V1
    # Actions for the user resource
    class UsersController < ApiController

      rescue_from ActiveRecord::RecordInvalid do |e|
        render_json_error :bad_request, :role_invalid
      end

      rescue_from ActiveRecord::RecordNotFound do |e|
        render_json_error :not_found, :user_not_found
      end

      def change_role
        @user = User.find(params[:user_id])

        @user.update!(change_role_params)

        render @user
      end

      def create
        # Users are created upon login from Single Sign On (Okta) and may not be created manually
        render_json_error :method_not_allowed, :user_cannot_be_created
      end

      def destroy
        # Users cannot be deleted
        render_json_error :method_not_allowed, :user_cannot_be_removed
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

      def change_role_params
        params.permit(
          :role
        )
      end

      def user_params
        params.permit(
          :preferred_language
        )
      end
    end
  end
end
