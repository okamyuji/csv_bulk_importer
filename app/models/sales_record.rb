# typed: true
# frozen_string_literal: true

class SalesRecord < ApplicationRecord
  belongs_to :csv_import, optional: true

  validates :recorded_on,
            :customer_code,
            :product_code,
            :quantity,
            :unit_price,
            :amount,
            :idempotency_key,
            presence: true
  validates :idempotency_key, uniqueness: true
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :unit_price, :amount, numericality: true
end
