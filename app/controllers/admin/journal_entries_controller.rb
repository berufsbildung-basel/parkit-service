# frozen_string_literal: true

module Admin
  class JournalEntriesController < BaseController
    def index
      @journal_entries = JournalEntry.includes(:user)
                                     .order(created_at: :desc)
                                     .page(params[:page])
                                     .per(25)
    end
  end
end
