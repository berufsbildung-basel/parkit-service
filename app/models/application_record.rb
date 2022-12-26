# frozen_string_literal: true

# Base class for all models
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # We order by created_at as we set the database to use UUIDs instead of integer IDs
  self.implicit_order_column = :created_at
end
