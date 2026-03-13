# frozen_string_literal: true

class UserBillingController < AuthorizableController
  def index
    @user = User.find(params[:user_id])
    authorize @user, :show?
    @reservations = policy_scope(@user.reservations.active.order(date: 'desc')).group_by do |reservation|
      reservation.date.end_of_month
    end
    @invoices = @user.invoices.order(period_start: :desc)
  end
end
