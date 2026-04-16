# typed: true
# frozen_string_literal: true

require "json"

# Structured audit logger. Emits a single line per event prefixed with AUDIT so
# CloudWatch Log Insights / jq can filter easily. The event body is always valid JSON
# and NEVER contains CSV row data, passwords, or raw JWTs.
#
# Example line:
#   AUDIT {"event":"csv_import.created","user_id":7,"csv_import_id":42, ... }
class AuditLogger
  REDACTED = "[REDACTED]"

  class << self
    def event(name, **payload)
      body = base_context.merge(event: name.to_s, at: Time.current.iso8601(3)).merge(sanitize(payload))
      Rails.logger.info("AUDIT #{body.to_json}")
    rescue StandardError => e
      # Logging must never crash the request. Fall back to plain logger.
      Rails.logger.warn("AuditLogger failed: #{e.class}: #{e.message}")
    end

    private

    def base_context
      { request_id: Current.request_id, user_id: Current.user_id, csv_import_id: Current.csv_import_id }.compact
    end

    # Allowlist-style sanitization. Reject nested CSV rows, long strings, binary,
    # and obvious secret-like keys. Callers are expected to already prepare scalar fields.
    def sanitize(hash)
      hash.each_with_object({}) { |(k, v), memo| memo[k] = secret_key?(k) ? REDACTED : safe_value(v) }
    end

    def secret_key?(key)
      %i[password token jwt secret csv_body rows raw].include?(key.to_sym)
    end

    def safe_value(value)
      case value
      when Hash
        value.transform_values { |v| safe_value(v) }
      when Array
        value.first(20).map { |v| safe_value(v) }
      when String
        value.length > 300 ? "#{value[0, 300]}…" : value
      when Numeric, TrueClass, FalseClass, NilClass, Symbol
        value
      else
        value.to_s[0, 300]
      end
    end
  end
end
