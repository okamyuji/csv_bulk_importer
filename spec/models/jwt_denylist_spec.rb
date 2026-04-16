# frozen_string_literal: true

require "rails_helper"

RSpec.describe JwtDenylist, type: :model do
  it "uses the devise-jwt Denylist strategy" do
    expect(described_class.ancestors).to include(Devise::JWT::RevocationStrategies::Denylist)
  end

  it "stores jti uniquely" do
    described_class.create!(jti: "abc", exp: 1.hour.from_now)
    expect { described_class.create!(jti: "abc", exp: 1.hour.from_now) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
