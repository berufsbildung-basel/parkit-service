# frozen_string_literal: true

module Api
  module V1
    # Base API controller
    class ApiController < ApplicationController
      rescue_from ActiveRecord::RecordInvalid do |e|
        render json: { error: { RecordInvalid: e.record.errors } }, status: 400
      end

      rescue_from ArgumentError do |e|
        render json: { error: e }, status: 400
      end

      def has_error?(resource, attribute, error)
        resource.errors.details.include?(attribute) &&
          resource.errors.details[attribute].select { |e| e[:error] == error }.size.positive?
      end

      def render_json_validation_error(resource, status = :bad_request)
        render json: resource, status:, adapter: :json_api, serializer: ActiveModel::Serializers::JSON
      end

      def render_json_error(status, error_code, extra = {})
        status = Rack::Utils::SYMBOL_TO_STATUS_CODE[status] if status.is_a? Symbol

        error = {
          title: I18n.t("error_messages.#{error_code}.title"),
          status:,
          code: I18n.t("error_messages.#{error_code}.code")
        }.merge(extra)

        detail = I18n.t("error_messages.#{error_code}.detail", default: '')
        error[:detail] = detail unless detail.empty?

        render json: { errors: [error] }, status:
      end

      def page_params
        params.permit(:page, :page_size)
      end
    end
  end
end
