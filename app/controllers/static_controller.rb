# frozen_string_literal: true

# Serves static pages
class StaticController < ApplicationController

  def welcome
    authorize current_user
  end

end
