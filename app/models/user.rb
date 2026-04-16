# typed: true
# frozen_string_literal: true

class User < ApplicationRecord
  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :validatable,
         :jwt_authenticatable,
         jwt_revocation_strategy: JwtDenylist

  validates :name, presence: true, length: { maximum: 50 }

  has_many :csv_imports, dependent: :destroy
end
