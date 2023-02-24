# frozen_string_literal: true

# Parent application controller
class ApplicationController < ActionController::Base

  include Pundit::Authorization
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  protect_from_forgery with: :exception, prepend: true

  before_action :authenticate_user!

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  def after_sign_in_path_for(resource)
    request.env['omniauth.origin'] || root_path
  end

  def user_not_authorized(exception)
    policy_name = exception.policy.class.to_s.underscore
    flash[:danger] = t "#{policy_name}.#{exception.query}", scope: 'pundit', default: :default
    redirect_to(request.referer || root_path)
  end
end
