# typed: true
# frozen_string_literal: true

class CsvImportFinalizerJob < ApplicationJob
  queue_as :csv_import

  def perform(csv_import_id)
    csv_import = CsvImport.find(csv_import_id)
    chunks = csv_import.csv_import_chunks
    return if chunks.where(status: %w[pending processing]).exists?

    total_processed = chunks.sum(:processed_rows)
    total_failed = chunks.sum(:failed_rows)
    failed_chunks = chunks.where(status: "failed").count
    partial_chunks = chunks.where(status: "completed_with_errors").count

    new_status =
      if failed_chunks.positive? && total_processed.zero?
        "failed"
      elsif failed_chunks.positive?
        "partially_failed"
      elsif partial_chunks.positive?
        "completed_with_errors"
      else
        "completed"
      end

    csv_import.update!(status: new_status, processed_rows: total_processed, failed_rows: total_failed)

    Current.csv_import_id = csv_import.id
    Current.user_id = csv_import.user_id
    AuditLogger.event(
      "csv_import.finalized",
      status: new_status,
      total_rows: csv_import.total_rows,
      processed_rows: total_processed,
      failed_rows: total_failed,
      failed_chunks: failed_chunks,
    )

    CsvImportChannel.broadcast_import_finalized(csv_import)
  end
end
