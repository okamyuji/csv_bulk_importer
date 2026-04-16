# frozen_string_literal: true

FactoryBot.define do
  factory :csv_import do
    association :user
    file_name { "sales.csv" }
    target_kind { "sales_record" }
    status { "pending" }
    sequence(:idempotency_key) { |n| "idem-#{n}-#{SecureRandom.hex(4)}" }
  end
end
