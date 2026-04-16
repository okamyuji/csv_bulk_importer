# frozen_string_literal: true

require "rails_helper"

RSpec.describe CsvRowMapper do
  describe ".call for sales_record" do
    let(:valid_row) do
      {
        "recorded_on" => "2026-04-01",
        "customer_code" => "C001",
        "product_code" => "P001",
        "quantity" => "3",
        "unit_price" => "120.50",
        "amount" => "361.50",
        "memo" => "ok",
      }
    end

    it "maps a valid row to attributes with an idempotency_key" do
      attrs = described_class.call(target_kind: "sales_record", row: valid_row, base_key: "abc")
      expect(attrs).to include(customer_code: "C001", quantity: 3)
      expect(attrs[:unit_price]).to eq(BigDecimal("120.50"))
      expect(attrs[:idempotency_key]).to match(/\A[0-9a-f]{64}\z/)
    end

    it "raises RowError on invalid date" do
      expect {
        described_class.call(target_kind: "sales_record", row: valid_row.merge("recorded_on" => "nope"), base_key: "x")
      }.to raise_error(CsvRowMapper::RowError, /invalid format/)
    end

    it "raises RowError on negative quantity" do
      expect {
        described_class.call(target_kind: "sales_record", row: valid_row.merge("quantity" => "-1"), base_key: "x")
      }.to raise_error(CsvRowMapper::RowError, /must be >= 0/)
    end

    it "raises RowError on non-numeric price" do
      expect {
        described_class.call(target_kind: "sales_record", row: valid_row.merge("unit_price" => "abc"), base_key: "x")
      }.to raise_error(CsvRowMapper::RowError, /not a decimal/)
    end

    it "gives identical rows the same idempotency_key but different base_keys yield different keys" do
      a = described_class.call(target_kind: "sales_record", row: valid_row, base_key: "one")
      b = described_class.call(target_kind: "sales_record", row: valid_row, base_key: "two")
      expect(a[:idempotency_key]).not_to eq(b[:idempotency_key])
    end
  end

  describe ".call for ledger_entry" do
    it "rejects rows where both debit and credit are zero" do
      row = {
        "posted_on" => "2026-04-01",
        "account_code" => "4000",
        "debit" => "0",
        "credit" => "0",
        "description" => "",
      }
      expect { described_class.call(target_kind: "ledger_entry", row: row, base_key: "x") }.to raise_error(
        CsvRowMapper::RowError,
        /debit or credit must be positive/,
      )
    end

    it "accepts a row where only debit is present" do
      row = {
        "posted_on" => "2026-04-01",
        "account_code" => "4000",
        "debit" => "1000",
        "credit" => "0",
        "description" => "rent",
      }
      attrs = described_class.call(target_kind: "ledger_entry", row: row, base_key: "x")
      expect(attrs[:debit]).to eq(BigDecimal("1000"))
      expect(attrs[:credit]).to eq(BigDecimal("0"))
    end
  end

  it "rejects unknown target_kind" do
    expect { described_class.call(target_kind: "bogus", row: {}, base_key: "x") }.to raise_error(
      CsvRowMapper::RowError,
      /unknown target_kind/,
    )
  end
end
