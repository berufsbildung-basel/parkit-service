class DropJournalEntries < ActiveRecord::Migration[7.1]
  def change
    drop_table :journal_entries
  end
end
