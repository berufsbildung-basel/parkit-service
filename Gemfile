# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.1.0'

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem 'rails', '7.0.4'

# Use sqlite3 as the database for Active Record
gem 'pg', '1.4.5'

# Use the Puma web server [https://github.com/puma/puma]
gem 'puma', '~> 5.0'

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# gem "jbuilder"

# Use the Devise gem for authentication
gem 'devise', '4.8.1'

# Use the gem as the OpenID connect client
gem 'omniauth-okta', '2.0.0'

# Use for configuration via yaml and env vars
gem 'figaro', '1.2.0'

# Use the Pundit gem for authorization
gem 'pundit', '2.2.0'

# For time-based validations
gem 'validates_timeliness', '7.0.0.beta1'

# For pagination
gem 'kaminari', '1.2.2'

# For JSON view templates
gem 'jbuilder', '2.11.5'

# Use Redis adapter to run Action Cable in production
# gem "redis", "~> 4.0"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin AJAX possible
# gem "rack-cors"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[mri mingw x64_mingw]
  gem 'faker'
  gem 'database_cleaner'
  gem 'rspec-rails', '6.0.1'
  gem 'rails-controller-testing'
  gem 'rubocop', require: false
  gem 'simplecov', require: false
end

group :development do
  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
end

