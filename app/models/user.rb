# frozen_string_literal: true

# The user represents an actor in the system and must be authenticated
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :rememberable

  has_many :reservations
  has_many :vehicles

  enum role: %i[user led_matrix admin]
  after_initialize :set_default_role, if: :new_record?

  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
  validates :oktaId, presence: true, uniqueness: true
  validates :username, presence: true, uniqueness: true

  def set_default_role
    self.role ||= :user
  end
end
