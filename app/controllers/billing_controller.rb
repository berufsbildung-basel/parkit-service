# frozen_string_literal: true

# Billing controller
class BillingController < AuthorizableController
  def index
    @users = policy_scope(User.all.order(:last_name))
    respond_to do |format|
      format.html
      format.xlsx do
        send_data Reservation.to_billing_xlsx(@users),
                  filename: "parkit-billing-export-#{DateTime.current.strftime('%Y%m%d%H%M%s')}.xlsx"
      end
    end
  end
end
