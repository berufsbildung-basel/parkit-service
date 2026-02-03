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
        authorize @user, :update?

        @user.update!(change_role_params)

        render @user
      end

      def create
        skip_authorization
        # Users are created upon login from Single Sign On (Okta) and may not be created manually
        render_json_error :method_not_allowed, :user_cannot_be_created
      end

      def destroy
        skip_authorization
        # Users cannot be deleted
        render_json_error :method_not_allowed, :user_cannot_be_removed
      end

      def disable
        @user = User.find(params[:user_id])
        authorize @user, :update?
        @user.disabled = true
        @user.save!
      end

      def enable
        @user = User.find(params[:user_id])
        authorize @user, :update?
        @user.disabled = false
        @user.save!
      end

      def index
        @users = policy_scope(User).page(page_params[:page]).per(page_params[:page_size])
      end

      def show
        @user = User.find(params[:id])
        authorize @user
      end

      def update
        @user = User.find(params[:id])
        authorize @user

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
