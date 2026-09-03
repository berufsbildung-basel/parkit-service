# frozen_string_literal: true

# Authorize access to vehicle resources
class ReservationPolicy < ApplicationPolicy
  # Scoped collection access
  class Scope < Scope
    def resolve
      if user.can_manage_reservations?
        scope.all
      else
        scope.where(user_id: user.id)
      end
    end
  end

  def edit?
    user.can_manage_reservations? || user.id == record.user_id
  end

  def update?
    edit?
  end

  def destroy?
    edit?
  end

  def cancel?
    edit?
  end

  def create?
    edit?
  end

  def new?
    edit?
  end

  def new_guest?
    user.can_manage_reservations?
  end

  def show?
    edit?
  end
end
