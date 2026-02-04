# frozen_string_literal: true

module ProfileHelper
  def country_options_for_select
    [
      %w[Switzerland CH],
      %w[Germany DE],
      %w[France FR],
      %w[Austria AT],
      %w[Italy IT],
      %w[Liechtenstein LI]
    ]
  end
end
