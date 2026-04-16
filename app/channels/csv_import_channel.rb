# typed: true
# frozen_string_literal: true

class CsvImportChannel < ApplicationCable::Channel
  def subscribed
    csv_import = CsvImport.find_by(id: params[:csv_import_id])
    return reject if csv_import.nil?

    user = current_user
    return reject if user.nil? || csv_import.user_id != user.id

    stream_for csv_import
  end

  def unsubscribed
    stop_all_streams
  end

  class << self
    def broadcast_split_started(csv_import)
      broadcast_to(
        csv_import,
        {
          event: "split_started",
          csv_import_id: csv_import.id,
          total_rows: csv_import.total_rows,
          total_chunks: csv_import.total_chunks,
        },
      )
    end

    def broadcast_chunk_completed(chunk)
      broadcast_to(
        chunk.csv_import,
        {
          event: "chunk_completed",
          csv_import_id: chunk.csv_import_id,
          chunk_id: chunk.id,
          chunk_index: chunk.chunk_index,
          status: chunk.status,
          processed_rows: chunk.processed_rows,
          failed_rows: chunk.failed_rows,
        },
      )
    end

    def broadcast_import_finalized(csv_import)
      broadcast_to(
        csv_import,
        {
          event: "import_finalized",
          csv_import_id: csv_import.id,
          status: csv_import.status,
          processed_rows: csv_import.processed_rows,
          failed_rows: csv_import.failed_rows,
        },
      )
    end
  end
end
