# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'billing rake tasks' do
  before(:all) do
    Rails.application.load_tasks
  end

  describe 'billing:sync_status' do
    it 'invokes InvoiceStatusSyncJob' do
      expect(InvoiceStatusSyncJob).to receive(:perform_now)
      Rake::Task['billing:sync_status'].reenable
      Rake::Task['billing:sync_status'].invoke
    end
  end

  describe 'billing:run' do
    it 'runs billing for previous month by default' do
      period_start = Date.today.last_month.beginning_of_month
      period_end = Date.today.last_month.end_of_month

      mock_results = {
        standard: { created: 0, skipped: 0 },
        prepaid: { created: 0, skipped: 0 },
        exempt: { skipped: 0 },
        errors: []
      }

      expect(BillingRunner).to receive(:new).with(
        period_start,
        period_end
      ).and_return(double(run: mock_results))

      Rake::Task['billing:run'].reenable
      Rake::Task['billing:run'].invoke
    end
  end
end
