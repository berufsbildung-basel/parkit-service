# frozen_string_literal: true

# Authorization policy for Invoice records
class InvoicePolicy < ApplicationPolicy
  def index?
    user&.can_manage_reservations?
  end

  def show?
    user&.can_manage_reservations?
  end

  def send_email?
    user&.can_manage_reservations?
  end

  def download_pdf?
    user&.can_manage_reservations?
  end

  def refresh_status?
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
