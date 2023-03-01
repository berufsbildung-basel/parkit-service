# frozen_string_literal: true

# User biling controller
class UserBillingController < AuthorizableController
  def index
    @user = User.find(params[:user_id])
    @reservations = policy_scope(@user.reservations.active_in_the_future.order(date: 'desc')).group_by do |reservation|
      reservation.date.end_of_month
    end
  end
end
