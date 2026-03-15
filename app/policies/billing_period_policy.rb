# frozen_string_literal: true

class BillingPeriodPolicy < ApplicationPolicy
  def show?
    user&.admin?
  end

  def reset?
    user&.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user&.admin?
        scope.all
      else
        scope.none
      end
    end
  end
end
