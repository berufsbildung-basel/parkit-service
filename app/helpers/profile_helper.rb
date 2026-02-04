# frozen_string_literal: true

module ProfileHelper
  def country_options_for_select
    [
      ['Switzerland', 'CH'],
      ['Germany', 'DE'],
      ['France', 'FR'],
      ['Austria', 'AT'],
      ['Italy', 'IT'],
      ['Liechtenstein', 'LI']
    ]
  end
end
