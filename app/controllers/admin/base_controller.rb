# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    before_action :require_admin!
    before_action :check_cashctrl_status

    private

    def require_admin!
      return if current_user&.admin?

      flash[:alert] = 'You are not authorized to access this page.'
      redirect_to root_path
    end

    def check_cashctrl_status
      config = Rails.application.config.cashctrl
      if config[:org].blank? || config[:api_key].blank?
        @cashctrl_status = :not_configured
        @cashctrl_org = nil
      else
        @cashctrl_org = config[:org]
        @cashctrl_status = CashctrlClient.new.ping ? :connected : :error
      end
    rescue StandardError
      @cashctrl_status = :error
    end
  end
end
