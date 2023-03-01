# frozen_string_literal: true

# Serves static pages
class DashboardController < AuthorizableController

  def welcome
    authorize current_user
    @reservation = current_user.reservations.new
    @reservations = current_user.reservations.active_in_the_future
  end

end
