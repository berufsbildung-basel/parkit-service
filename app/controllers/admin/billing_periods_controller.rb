# frozen_string_literal: true

module Admin
  class BillingPeriodsController < BaseController
    def show
      @billing_period = BillingPeriod.find(params[:id])
      @invoices = Invoice.includes(:user)
                         .for_period(@billing_period.period_start)
                         .order(created_at: :desc)
      @skipped_users = compute_skipped_users
    end

    def reset
      billing_period = BillingPeriod.find(params[:id])
      invoices = Invoice.for_period(billing_period.period_start)

      # Delete from CashCtrl first
      cashctrl_ids = invoices.where.not(cashctrl_invoice_id: nil).pluck(:cashctrl_invoice_id)
      CashctrlClient.new.delete_invoices(cashctrl_ids) if cashctrl_ids.any?

      invoice_count = invoices.count
      invoices.destroy_all
      billing_period.destroy!

      redirect_to admin_billing_path,
                  notice: "Period #{billing_period.period_start.strftime('%B %Y')} reset (#{invoice_count} invoices deleted locally and in CashCtrl)."
    rescue StandardError => e
      redirect_to admin_billing_path,
                  alert: "Failed to reset period: #{e.message}"
    end

    private

    def compute_skipped_users
      period_start = @billing_period.period_start
      period_end = @billing_period.period_end

      users_with_reservations = User.joins(:reservations)
                                    .where(reservations: { date: period_start..period_end })
                                    .distinct

      skipped = []

      users_with_reservations.standard_billing.each do |user|
        has_invoice = Invoice.exists?(user: user, period_start: period_start)
        total = user.reservations.where(date: period_start..period_end, cancelled: false).sum(:price)

        if has_invoice
          next # Not skipped - was invoiced
        elsif total <= 0
          skipped << { user: user, reason: 'Zero total (weekend/cancelled reservations only)' }
        end
      end

      users_with_reservations.prepaid_billing.each do |user|
        has_invoice = Invoice.exists?(user: user, period_start: period_start)
        total = user.reservations.where(date: period_start..period_end, cancelled: false).sum(:price)

        if has_invoice
          next
        elsif total <= 0
          skipped << { user: user, reason: 'Zero total (weekend/cancelled reservations only)' }
        end
      end

      skipped
    end
  end
end
