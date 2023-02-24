# frozen_string_literal: true

# Serves static pages
class DashboardController < ApplicationController

  def welcome
    authorize current_user
    @reservation = current_user.reservations.new
  end

end
