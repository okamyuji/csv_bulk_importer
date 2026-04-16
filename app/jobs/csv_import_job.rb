# typed: true
# frozen_string_literal: true

class CsvImportJob < ApplicationJob
  queue_as :csv_import

  def perform(csv_import_id)
    csv_import = CsvImport.find(csv_import_id)
    Current.csv_import_id = csv_import.id
    Current.user_id = csv_import.user_id
    return unless %w[pending failed].include?(csv_import.status)

    csv_import.update!(status: "splitting", error_message: nil, s3_prefix: csv_import.s3_prefix_or_default)
    AuditLogger.event("csv_import.splitting_started")

    result =
      open_source(csv_import) do |io|
        CsvChunkSplitter.call(
          io: io,
          s3_prefix: csv_import.s3_prefix_or_default,
          bucket: AppS3.bucket,
          s3_client: AppS3.client,
        )
      end

    CsvImport.transaction do
      csv_import.update!(status: "processing", total_rows: result.total_rows, total_chunks: result.total_chunks)

      result.chunks.each do |c|
        csv_import.csv_import_chunks.create!(
          chunk_index: c.index,
          start_row: c.start_row,
          end_row: c.end_row,
          status: "pending",
          s3_key: c.s3_key,
        )
      end
    end

    broadcast_split_started(csv_import)

    csv_import.csv_import_chunks.order(:chunk_index).pluck(:id).each { |cid| CsvChunkJob.perform_later(cid) }
  rescue StandardError => e
    CsvImport.where(id: csv_import_id).update_all(status: "failed", error_message: e.message)
    AuditLogger.event("csv_import.splitting_failed", error_class: e.class.name, error_message: e.message[0, 200])
    raise
  end

  private

  # Yields an IO opened in UTF-8 w/ BOM stripping. Uses ActiveStorage blob#open,
  # which downloads to a Tempfile and deletes it when the block exits.
  def open_source(csv_import)
    csv_import.source_file.open { |tempfile| File.open(tempfile.path, "r:bom|utf-8") { |io| yield io } }
  end

  def broadcast_split_started(csv_import)
    CsvImportChannel.broadcast_split_started(csv_import)
    Rails.logger.info(
      "[CsvImportJob] split_started csv_import_id=#{csv_import.id} rows=#{csv_import.total_rows} chunks=#{csv_import.total_chunks}",
    )
  end
end
