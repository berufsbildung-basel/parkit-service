# frozen_string_literal: true

class BillingPeriod < ApplicationRecord
  belongs_to :executed_by, class_name: 'User', optional: true

  enum status: { unbilled: 0, in_progress: 1, completed: 2, partially_failed: 3 }

  validates :period_start, presence: true, uniqueness: true
  validates :period_end, presence: true
end
