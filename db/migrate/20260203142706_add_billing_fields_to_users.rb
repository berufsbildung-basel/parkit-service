# frozen_string_literal: true

class AddBillingFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :billing_type, :integer, null: false, default: 0
    add_column :users, :cashctrl_person_id, :integer
    add_column :users, :cashctrl_private_account_id, :integer
    add_column :users, :prepaid_threshold, :decimal, precision: 10, scale: 2
    add_column :users, :prepaid_topup_amount, :decimal, precision: 10, scale: 2

    add_index :users, :billing_type
    add_index :users, :cashctrl_person_id
  end
end
