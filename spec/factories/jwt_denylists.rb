FactoryBot.define do
  factory :jwt_denylist do
    jti { "MyString" }
    exp { "2026-04-16 08:30:33" }
  end
end
