class RemoveJournalColumnsFromBillingPeriods < ActiveRecord::Migration[7.1]
  def change
    remove_column :billing_periods, :journal_entries_created, :integer
    remove_column :billing_periods, :topup_invoices_created, :integer
  end
end
