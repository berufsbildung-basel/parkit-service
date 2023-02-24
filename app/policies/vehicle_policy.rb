# frozen_string_literal: true

# Authorize access to vehicle resources
class VehiclePolicy < ApplicationPolicy
  # Scoped collection access
  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.none
      end
    end
  end

  def edit?
    user.admin? or user.id == record.user_id
  end

  def update?
    edit?
  end

  def destroy?
    edit?
  end

  def create?
    true
  end

  def show?
    edit?
  end
end
