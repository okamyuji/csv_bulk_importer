# typed: true
# frozen_string_literal: true

class LedgerEntry < ApplicationRecord
  belongs_to :csv_import, optional: true

  validates :posted_on, :account_code, :idempotency_key, presence: true
  validates :idempotency_key, uniqueness: true
  validates :debit, :credit, numericality: true
  validate :debit_or_credit_present

  private

  def debit_or_credit_present
    return if debit.to_d.positive? || credit.to_d.positive?

    errors.add(:base, "either debit or credit must be positive")
  end
end
