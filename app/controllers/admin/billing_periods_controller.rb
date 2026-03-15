# frozen_string_literal: true

module Admin
  class BillingPeriodsController < BaseController
    def show
      @billing_period = BillingPeriod.find(params[:id])
      @invoices = Invoice.includes(:user)
                         .for_period(@billing_period.period_start)
                         .order(created_at: :desc)
    end
  end
end
