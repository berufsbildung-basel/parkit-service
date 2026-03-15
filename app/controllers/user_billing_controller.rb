# frozen_string_literal: true

class UserBillingController < AuthorizableController
  def index
    @user = User.find(params[:user_id])
    authorize @user, :show?
    @reservations = policy_scope(@user.reservations.active.order(date: 'desc')).group_by do |reservation|
      reservation.date.end_of_month
    end
    @invoices = @user.invoices.order(period_start: :desc)

    if @user.prepaid? && @user.cashctrl_private_account_id.present?
      begin
        @prepaid_balance = CashctrlClient.new.get_account_balance(@user.cashctrl_private_account_id)
      rescue StandardError => e
        Rails.logger.warn("Failed to fetch prepaid balance for user #{@user.id}: #{e.message}")
        @prepaid_balance = nil
      end
    end
  end
end
