# frozen_string_literal: true

# User controller
class UsersController < AuthorizableController

  def edit
    @user = User.find(params[:id])
    authorize @user
  end

  def index
    @users = policy_scope(User.all.order(:last_name))
  end

  def show
    @user = User.find(params[:id])
    authorize @user
    @reservations = @user.reservations.active_in_the_future
  end

  def update
    @user = User.find(params[:id])
    authorize @user

    if @user.update(user_params)
      respond_to do |format|
        flash[:success] = 'User was successfully updated.'
        format.html { redirect_to user_path(@user.id) }
      end
    else
      respond_to do |format|
        flash[:danger] = 'There was a problem updating the user.'
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
        :role,
        :disabled
      )
    else
      params.require(:user).permit([])
    end
  end
end
