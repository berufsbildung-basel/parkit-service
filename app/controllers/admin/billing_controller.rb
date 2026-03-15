# frozen_string_literal: true

module Admin
  class BillingController < BaseController
    def show
      @billing_periods = BillingPeriod.order(period_start: :desc)
      @stats = {
        total_open: Invoice.open.sum(:total_amount)
      }
    end

    def run
      @available_months = available_months_for_billing
    end

    def preview
      period = parse_period(params[:period])
      runner = BillingRunner.new(period[:start], period[:end])
      @preview = runner.preview
      @period = period
    end

    def execute
      period = parse_period(params[:period])
      runner = BillingRunner.new(period[:start], period[:end], executed_by: current_user)
      @result = runner.run

      redirect_to admin_billing_path, notice: billing_notice(@result)
    end

    private

    def available_months_for_billing
      billing_start = Rails.application.config.cashctrl[:billing_start_date] || 6.months.ago.to_date
      start_month = billing_start.beginning_of_month
      end_month = 1.month.ago.to_date.beginning_of_month

      completed_months = BillingPeriod.completed.pluck(:period_start)

      months = []
      current = end_month
      while current >= start_month
        unless completed_months.include?(current)
          months << { start: current, end: current.end_of_month, label: current.strftime('%B %Y') }
        end
        current -= 1.month
      end
      months.reverse
    end

    def parse_period(period_string)
      date = Date.parse(period_string)
      { start: date.beginning_of_month, end: date.end_of_month }
    end

    def billing_notice(result)
      parts = []
      parts << "Standard: #{result[:standard][:created]} invoices" if result[:standard][:created] > 0
      parts << "Prepaid: #{result[:prepaid][:created]} statement invoices" if result[:prepaid][:created] > 0
      parts << "Exempt: #{result[:exempt][:skipped]} skipped" if result[:exempt][:skipped] > 0
      parts.empty? ? 'No billing actions taken' : parts.join(', ')
    end
  end
end
