# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  subject { build(:user) }

  it { is_expected.to validate_presence_of(:name) }

  it "enforces unique email" do
    create(:user, email: "dup@example.com")
    dup = build(:user, email: "dup@example.com")
    expect(dup).not_to be_valid
    expect(dup.errors[:email]).to include(/taken/i)
  end

  it { is_expected.to have_many(:csv_imports).dependent(:destroy) }
end
