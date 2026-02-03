# frozen_string_literal: true

# spec/support/spec_test_helper.rb
module SpecTestHelper
  def login_admin
    admin = User.find_or_create_by!(username: 'admin') do |u|
      u.email = 'admin@test.com'
      u.first_name = 'Admin'
      u.last_name = 'User'
      u.role = :admin
    end
    login(admin)
  end

  def login(user)
    user = User.find_by(username: user.to_s) if user.is_a?(Symbol)
    if defined?(request) && request.present?
      request.session[:user] = user.id
    else
      # For request specs, stub the current_user on API controllers
      @current_test_user = user
      allow_any_instance_of(Api::ApplicationController).to receive(:current_user).and_return(user)
      allow_any_instance_of(Api::ApplicationController).to receive(:pundit_user).and_return(user)
    end
  end

  def current_user
    @current_test_user || (defined?(request) && request.present? ? User.find(request.session[:user]) : nil)
  end
end

# spec/spec_helper.rb
RSpec.configure do |config|
  config.include SpecTestHelper, type: :controller
  config.include SpecTestHelper, type: :request
end
