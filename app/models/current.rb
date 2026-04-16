# typed: true
# frozen_string_literal: true

# Per-request / per-job ambient context so AuditLogger can enrich every event
# with request_id + user_id without threading them through call signatures.
class Current < ActiveSupport::CurrentAttributes
  attribute :request_id, :user_id, :csv_import_id
end
