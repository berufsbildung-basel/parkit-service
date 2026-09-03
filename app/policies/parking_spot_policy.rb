# frozen_string_literal: true

# Authorize access to vehicle resources
class ParkingSpotPolicy < ApplicationPolicy
  # Scoped collection access
  class Scope < Scope
    def resolve
      if user.can_manage_reservations?
        scope.all
      else
        scope.none
      end
    end
  end

  def edit?
    user.can_manage_reservations?
  end

  def update?
    edit?
  end

  def destroy?
    edit?
  end

  def new?
    edit?
  end

  def create?
    edit?
  end

  def show?
    edit?
  end

  def archive?
    edit?
  end

  def unarchive?
    edit?
  end
end
