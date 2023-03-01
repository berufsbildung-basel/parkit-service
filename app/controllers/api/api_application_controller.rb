# frozen_string_literal: true

# API base controller
class ApiApplicationController < ActionController::API

  include Pundit::Authorization

  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  def user_not_authorized(exception)
    policy_name = exception.policy.class.to_s.underscore
    flash[:danger] = t "#{policy_name}.#{exception.query}", scope: 'pundit', default: :default
    redirect_to(request.referer || root_path)
  end
end
