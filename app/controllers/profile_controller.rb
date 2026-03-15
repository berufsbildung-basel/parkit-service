# frozen_string_literal: true

class ProfileController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
  end

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    if @user.update(profile_params)
      sync_to_cashctrl(@user)
      redirect_to profile_path, notice: t('.success')
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:user).permit(
      :first_name, :last_name, :preferred_language,
      :address_line1, :address_line2, :postal_code, :city, :country_code
    )
  end

  def sync_to_cashctrl(user)
    return unless user.cashctrl_person_id.present?

    CashctrlClient.new.update_person(user)
  rescue StandardError => e
    Rails.logger.error("CashCtrl sync failed: #{e.message}")
    flash[:warning] = t('.cashctrl_sync_failed')
  end
end
