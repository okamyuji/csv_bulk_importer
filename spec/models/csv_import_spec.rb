# frozen_string_literal: true

require "rails_helper"

RSpec.describe CsvImport do
  describe "validations" do
    it { is_expected.to validate_presence_of(:file_name) }
    it { is_expected.to validate_inclusion_of(:target_kind).in_array(%w[sales_record ledger_entry]) }
    it { is_expected.to validate_inclusion_of(:status).in_array(CsvImport::STATUSES) }

    it "enforces unique idempotency_key at the DB level" do
      create(:csv_import, idempotency_key: "same")
      expect { create(:csv_import, idempotency_key: "same") }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe "#completed?" do
    it "returns true for terminal statuses" do
      %w[completed completed_with_errors partially_failed failed].each do |s|
        expect(build(:csv_import, status: s)).to be_completed
      end
    end

    it "returns false for in-progress statuses" do
      %w[pending splitting processing].each { |s| expect(build(:csv_import, status: s)).not_to be_completed }
    end
  end
end
