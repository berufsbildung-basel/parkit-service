# frozen_string_literal: true

module Admin
  class BillingController < BaseController
    def show
      @stats = {
        total_open: Invoice.open.sum(:total_amount),
        invoices_by_status: Invoice.group(:status).count,
        journal_entries_this_month: JournalEntry.where(period_start: Date.today.beginning_of_month).count
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
      runner = BillingRunner.new(period[:start], period[:end])
      @result = runner.run

      redirect_to admin_billing_path, notice: billing_notice(@result)
    end

    private

    def available_months_for_billing
      billing_start = Rails.application.config.cashctrl[:billing_start_date] || 6.months.ago.to_date
      start_month = billing_start.beginning_of_month
      end_month = 1.month.ago.beginning_of_month

      months = []
      current = end_month
      while current >= start_month
        months << { start: current, end: current.end_of_month, label: current.strftime('%B %Y') }
        current -= 1.month
      end
      months
    end

    def parse_period(period_string)
      date = Date.parse(period_string)
      { start: date.beginning_of_month, end: date.end_of_month }
    end

    def billing_notice(result)
      parts = []
      parts << "Standard: #{result[:standard][:created]} invoices" if result[:standard][:created] > 0
      if result[:prepaid][:journal_entries_created] > 0
        parts << "Prepaid: #{result[:prepaid][:journal_entries_created]} journal entries"
      end
      parts << "#{result[:prepaid][:topup_invoices_created]} top-up invoices" if result[:prepaid][:topup_invoices_created] > 0
      parts << "Exempt: #{result[:exempt][:skipped]} skipped" if result[:exempt][:skipped] > 0
      parts.empty? ? 'No billing actions taken' : parts.join(', ')
    end
  end
end
