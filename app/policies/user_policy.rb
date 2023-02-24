# frozen_string_literal: true

# Authorize access to user resources
class UserPolicy < ApplicationPolicy
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
    user.admin? or user.id == record.id
  end

  def update?
    edit?
  end

  def create?
    edit?
  end

  def show?
    edit?
  end

  def welcome?
    true
  end
end
