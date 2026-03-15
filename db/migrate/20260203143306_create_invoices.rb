# frozen_string_literal: true

class CreateInvoices < ActiveRecord::Migration[7.1]
  def change
    create_table :invoices, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.integer :cashctrl_invoice_id
      t.integer :cashctrl_person_id, null: false
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.decimal :total_amount, precision: 10, scale: 2, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.string :cashctrl_status
      t.datetime :sent_at
      t.datetime :paid_at

      t.timestamps
    end

    add_index :invoices, :cashctrl_invoice_id
    add_index :invoices, :status
    add_index :invoices, [:user_id, :period_start], unique: true
  end
end
