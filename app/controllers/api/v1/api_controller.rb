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

      def page_params
        params.permit(:page, :page_size)
      end
    end
  end
end
