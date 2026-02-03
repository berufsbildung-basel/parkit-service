# frozen_string_literal: true

class Invoice < ApplicationRecord
  belongs_to :user
  has_many :line_items, class_name: 'InvoiceLineItem', dependent: :destroy

  enum status: { draft: 0, sent: 1, paid: 2, cancelled: 3 }

  validates :cashctrl_person_id, presence: true
  validates :period_start, presence: true
  validates :period_end, presence: true
  validates :user_id, uniqueness: { scope: :period_start }

  scope :open, -> { where(status: %i[draft sent]) }
  scope :for_period, ->(start_date) { where(period_start: start_date) }
end
