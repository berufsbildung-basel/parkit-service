# frozen_string_literal: true

# Authorization policy for Invoice records
class InvoicePolicy < ApplicationPolicy
  def index?
    user&.admin?
  end

  def show?
    user&.admin?
  end

  def send_email?
    user&.admin?
  end

  def download_pdf?
    user&.admin?
  end

  def refresh_status?
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
