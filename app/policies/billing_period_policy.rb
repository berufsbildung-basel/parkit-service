# frozen_string_literal: true

class BillingPeriodPolicy < ApplicationPolicy
  def show?
    user&.can_manage_reservations?
  end

  def reset?
    user&.can_manage_reservations?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user&.can_manage_reservations?
        scope.all
      else
        scope.none
      end
    end
  end
end
