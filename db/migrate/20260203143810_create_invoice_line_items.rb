# frozen_string_literal: true

class CreateInvoiceLineItems < ActiveRecord::Migration[7.1]
  def change
    create_table :invoice_line_items, id: :uuid do |t|
      t.references :invoice, null: false, foreign_key: true, type: :uuid
      t.references :reservation, null: false, foreign_key: true, type: :uuid
      t.string :description, null: false
      t.integer :quantity, null: false, default: 1
      t.decimal :unit_price, precision: 10, scale: 2, null: false

      t.timestamps
    end
  end
end
