# frozen_string_literal: true

class JournalEntry < ApplicationRecord
  belongs_to :user

  validates :period_start, presence: true
  validates :period_end, presence: true
  validates :user_id, uniqueness: { scope: :period_start }

  scope :for_period, ->(start_date) { where(period_start: start_date) }
end
