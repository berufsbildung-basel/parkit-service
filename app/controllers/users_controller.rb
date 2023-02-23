# frozen_string_literal: true

# User controller
class UsersController < ApplicationController

  # Enforces access right checks for individuals resources
  after_action :verify_authorized, except: [:index]

  # Enforces access right checks for collections
  after_action :verify_policy_scoped, only: [:index]

  def edit
    @user = User.find(params[:id])
    authorize @user
  end

  def index
    @users = policy_scope(User.all)
  end

  def show
    @user = User.find(params[:id])
    authorize @user
  end

  def update
    @user = User.find(params[:id])
    authorize @user

    if @user.update(user_params)
      respond_to do |format|
        flash[:success] = 'user was successfully deleted.'
        format.html { redirect_to user_path(@user.id) }
      end
    else
      respond_to do |format|
        flash[:danger] = 'There was a problem udpating the User.'
        format.html { render :edit }
      end
    end
  end

  private

  def user_params
    if current_user.admin?
      params.require(:user).permit(
        :password,
        :password_confirmation,
        :role
      )
    else
      params.require(:user).permit([])
    end
  end
end
