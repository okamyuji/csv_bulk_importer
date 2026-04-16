# typed: true
# frozen_string_literal: true

require "bigdecimal"
require "digest"

# Converts a parsed CSV row (hash from CSV.foreach headers: true) into
# a validated attributes hash for upsert_all.
# Raises RowError on type/format failure so the caller can capture the row_num + message.
class CsvRowMapper
  class RowError < StandardError
  end

  SALES_COLUMNS = %w[recorded_on customer_code product_code quantity unit_price amount memo].freeze
  LEDGER_COLUMNS = %w[posted_on account_code debit credit description].freeze

  class << self
    def call(target_kind:, row:, base_key:)
      case target_kind
      when "sales_record"
        map_sales(row, base_key)
      when "ledger_entry"
        map_ledger(row, base_key)
      else
        raise RowError, "unknown target_kind: #{target_kind.inspect}"
      end
    end

    def expected_headers(target_kind)
      case target_kind
      when "sales_record"
        SALES_COLUMNS
      when "ledger_entry"
        LEDGER_COLUMNS
      else
        raise RowError, "unknown target_kind: #{target_kind.inspect}"
      end
    end

    private

    def map_sales(row, base_key)
      recorded_on = parse_date(row["recorded_on"], "recorded_on")
      customer_code = require_string(row["customer_code"], "customer_code", 32)
      product_code = require_string(row["product_code"], "product_code", 32)
      quantity = parse_integer(row["quantity"], "quantity")
      unit_price = parse_decimal(row["unit_price"], "unit_price")
      amount = parse_decimal(row["amount"], "amount")
      memo = optional_string(row["memo"], 255)

      raise RowError, "quantity must be >= 0" if quantity.negative?

      {
        recorded_on: recorded_on,
        customer_code: customer_code,
        product_code: product_code,
        quantity: quantity,
        unit_price: unit_price,
        amount: amount,
        memo: memo,
        idempotency_key:
          idempotency(
            "sales",
            base_key,
            [recorded_on, customer_code, product_code, quantity, unit_price, amount, memo],
          ),
      }
    end

    def map_ledger(row, base_key)
      posted_on = parse_date(row["posted_on"], "posted_on")
      account_code = require_string(row["account_code"], "account_code", 16)
      debit = parse_decimal(row["debit"].presence || "0", "debit")
      credit = parse_decimal(row["credit"].presence || "0", "credit")
      description = optional_string(row["description"], 255)

      raise RowError, "debit or credit must be positive" unless debit.positive? || credit.positive?

      {
        posted_on: posted_on,
        account_code: account_code,
        debit: debit,
        credit: credit,
        description: description,
        idempotency_key: idempotency("ledger", base_key, [posted_on, account_code, debit, credit, description]),
      }
    end

    def parse_date(value, name)
      raise RowError, "#{name} is blank" if value.to_s.strip.empty?

      Date.parse(value.to_s.strip)
    rescue ArgumentError, TypeError
      raise RowError, "#{name} has invalid format: #{value.inspect}"
    end

    def parse_integer(value, name)
      raise RowError, "#{name} is blank" if value.to_s.strip.empty?

      Integer(value.to_s.strip, 10)
    rescue ArgumentError, TypeError
      raise RowError, "#{name} is not an integer: #{value.inspect}"
    end

    def parse_decimal(value, name)
      BigDecimal(value.to_s.strip)
    rescue ArgumentError, TypeError
      raise RowError, "#{name} is not a decimal: #{value.inspect}"
    end

    def require_string(value, name, max)
      v = value.to_s.strip
      raise RowError, "#{name} is blank" if v.empty?
      raise RowError, "#{name} exceeds #{max} chars" if v.length > max

      v
    end

    def optional_string(value, max)
      v = value.to_s.strip
      return nil if v.empty?
      raise RowError, "value exceeds #{max} chars" if v.length > max

      v
    end

    def idempotency(kind, base_key, parts)
      Digest::SHA256.hexdigest("#{base_key}|#{kind}|#{parts.join("|")}")
    end
  end
end
