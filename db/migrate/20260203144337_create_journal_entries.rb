# frozen_string_literal: true

class CreateJournalEntries < ActiveRecord::Migration[7.1]
  def change
    create_table :journal_entries, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.integer :cashctrl_journal_id
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.decimal :total_amount, precision: 10, scale: 2, null: false, default: 0
      t.integer :reservation_count, null: false, default: 0

      t.timestamps
    end

    add_index :journal_entries, :cashctrl_journal_id
    add_index :journal_entries, [:user_id, :period_start], unique: true
  end
end
