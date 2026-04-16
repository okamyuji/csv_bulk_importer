# typed: true
# frozen_string_literal: true

class CsvImportPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    record.user_id == user.id
  end

  def create?
    user.present?
  end

  def retry?
    show?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user_id: user.id)
    end
  end
end
