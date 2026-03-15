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

  def language_options_for_select
    [
      %w[English en],
      %w[Deutsch de],
      ['Français', 'fr'],
      %w[Italiano it]
    ]
  end
end
