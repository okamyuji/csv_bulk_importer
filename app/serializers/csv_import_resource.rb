# typed: true
# frozen_string_literal: true

class CsvImportResource
  include Alba::Resource

  attributes :id,
             :file_name,
             :target_kind,
             :status,
             :total_rows,
             :processed_rows,
             :failed_rows,
             :total_chunks,
             :idempotency_key,
             :error_message,
             :created_at,
             :updated_at

  attribute :progress do |imp|
    next 0 if imp.total_rows.to_i.zero?

    ((imp.processed_rows.to_f + imp.failed_rows.to_f) / imp.total_rows * 100).round(1)
  end
end
