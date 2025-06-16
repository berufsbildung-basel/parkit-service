# frozen_string_literal: true

require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.ˆ
Bundler.require(*Rails.groups)

module ParkitService
  RESERVATION_MAX_WEEKS_INTO_THE_FUTURE = 2
  RESERVATION_MAX_RESERVATIONS_PER_DAY = 1
  RESERVATION_MAX_RESERVATIONS_PER_WEEK = 3

  RESERVATION_PRICE_CAR_HALF_DAY = 10
  RESERVATION_PRICE_CAR_FULL_DAY = 20
  RESERVATION_PRICE_MOTORCYCLE_HALF_DAY = 2.5
  RESERVATION_PRICE_MOTORCYCLE_FULL_DAY = 5

  # Main application
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = 'Europe/Zurich'
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
