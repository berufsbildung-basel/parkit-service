# frozen_string_literal: true

namespace :billing do
  desc 'Sync invoice status from CashCtrl'
  task sync_status: :environment do
    puts 'Syncing invoice status from CashCtrl...'
    InvoiceStatusSyncJob.perform_now
    puts 'Done.'
  end

  desc 'Run billing for previous month (or specify MONTH=YYYY-MM)'
  task run: :environment do
    if ENV['MONTH']
      date = Date.parse("#{ENV['MONTH']}-01")
      period_start = date.beginning_of_month
      period_end = date.end_of_month
    else
      period_start = Date.today.last_month.beginning_of_month
      period_end = Date.today.last_month.end_of_month
    end

    puts "Running billing for #{period_start.strftime('%B %Y')}..."
    runner = BillingRunner.new(period_start, period_end)
    results = runner.run

    puts "\nResults:"
    puts "  Standard: #{results[:standard][:created]} invoices created, #{results[:standard][:skipped]} skipped"
    puts "  Prepaid: #{results[:prepaid][:journal_entries_created]} journal entries, #{results[:prepaid][:topup_invoices_created]} top-up invoices"
    puts "  Exempt: #{results[:exempt][:skipped]} skipped"

    if results[:errors].any?
      puts "\nErrors:"
      results[:errors].each { |e| puts "  - #{e}" }
    end
  end
end
