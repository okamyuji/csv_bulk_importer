# frozen_string_literal: true

require "rails_helper"

RSpec.describe CsvImportPolicy do
  let(:owner) { create(:user) }
  let(:other) { create(:user) }
  let(:record) { create(:csv_import, user: owner) }

  it "allows the owner to view and retry" do
    expect(described_class.new(owner, record).show?).to be true
    expect(described_class.new(owner, record).retry?).to be true
  end

  it "denies other users" do
    expect(described_class.new(other, record).show?).to be false
    expect(described_class.new(other, record).retry?).to be false
  end

  it "limits Scope to the current user's records" do
    mine = create(:csv_import, user: owner)
    _theirs = create(:csv_import, user: other)
    scope = described_class::Scope.new(owner, CsvImport).resolve
    expect(scope).to contain_exactly(mine, record)
  end
end
