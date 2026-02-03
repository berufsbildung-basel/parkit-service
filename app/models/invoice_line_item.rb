# frozen_string_literal: true

class InvoiceLineItem < ApplicationRecord
  belongs_to :invoice
  belongs_to :reservation

  validates :description, presence: true
  validates :unit_price, presence: true
end
