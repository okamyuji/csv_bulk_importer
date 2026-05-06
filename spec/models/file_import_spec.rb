# frozen_string_literal: true

require "rails_helper"

RSpec.describe FileImport do
  describe "validations" do
    it { is_expected.to validate_presence_of(:file_name) }
    it { is_expected.to validate_inclusion_of(:input_kind).in_array(FileImport::INPUT_KINDS) }
    it { is_expected.to validate_inclusion_of(:target_kind).in_array(FileImport::TARGET_KINDS) }
    it { is_expected.to validate_inclusion_of(:status).in_array(FileImport::STATUSES) }

    it "enforces unique idempotency_key at the DB level" do
      create(:file_import, idempotency_key: "same")
      expect { create(:file_import, idempotency_key: "same") }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "rejects a binary target for CSV imports" do
      file_import = build(:file_import, input_kind: "csv", target_kind: "binary_asset")
      expect(file_import).not_to be_valid
      expect(file_import.errors[:target_kind]).to be_present
    end

    it "accepts the binary target for binary imports" do
      file_import = build(:file_import, input_kind: "binary", target_kind: "binary_asset")
      expect(file_import).to be_valid
    end
  end

  describe "#completed?" do
    it "returns true for terminal statuses" do
      %w[completed completed_with_errors partially_failed failed].each do |s|
        expect(build(:file_import, status: s)).to be_completed
      end
    end

    it "returns false for in-progress statuses" do
      %w[pending splitting processing].each { |s| expect(build(:file_import, status: s)).not_to be_completed }
    end
  end
end
