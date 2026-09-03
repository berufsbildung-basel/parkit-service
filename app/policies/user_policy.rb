# frozen_string_literal: true

# Authorize access to user resources
class UserPolicy < ApplicationPolicy
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

  # Editing/creating users (role, disabled, billing type) stays admin-only.
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
    user.can_manage_reservations? or user.id == record.id
  end

  def create_topup_invoice?
    user.can_manage_reservations?
  end

  def welcome?
    true
  end
end
