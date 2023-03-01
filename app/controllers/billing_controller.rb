# frozen_string_literal: true

# Billing controller
class BillingController < AuthorizableController
  def index
    @users = policy_scope(User.all.order(:last_name))
  end
end
