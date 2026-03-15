class MakeReservationIdNullableOnInvoiceLineItems < ActiveRecord::Migration[7.1]
  def change
    change_column_null :invoice_line_items, :reservation_id, true
  end
end
