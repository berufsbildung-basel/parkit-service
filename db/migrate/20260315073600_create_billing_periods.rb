# frozen_string_literal: true

class CreateBillingPeriods < ActiveRecord::Migration[7.1]
  def change
    create_table :billing_periods, id: :uuid do |t|
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.integer :status, null: false, default: 0
      t.integer :invoices_created, null: false, default: 0
      t.integer :invoices_skipped, null: false, default: 0
      t.integer :journal_entries_created, null: false, default: 0
      t.integer :topup_invoices_created, null: false, default: 0
      t.integer :exempt_skipped, null: false, default: 0
      t.jsonb :errors_log, null: false, default: []
      t.references :executed_by, null: true, foreign_key: { to_table: :users }, type: :uuid
      t.datetime :executed_at

      t.timestamps
    end

    add_index :billing_periods, :period_start, unique: true
    add_index :billing_periods, :status
  end
end
