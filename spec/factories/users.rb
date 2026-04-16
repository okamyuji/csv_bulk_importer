# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "secret123" }
    password_confirmation { "secret123" }
    sequence(:name) { |n| "User #{n}" }
  end
end
