# typed: true
# frozen_string_literal: true

class FileImportChannel < ApplicationCable::Channel
  def subscribed
    file_import = FileImport.find_by(id: params[:file_import_id])
    return reject if file_import.nil?

    user = current_user
    return reject if user.nil? || file_import.user_id != user.id

    stream_for file_import
  end

  def unsubscribed
    stop_all_streams
  end

  class << self
    def broadcast_split_started(file_import)
      broadcast_to(
        file_import,
        {
          event: "split_started",
          file_import_id: file_import.id,
          input_kind: file_import.input_kind,
          total_rows: file_import.total_rows,
          total_bytes: file_import.total_bytes,
          total_chunks: file_import.total_chunks,
        },
      )
    end

    def broadcast_chunk_completed(chunk)
      broadcast_to(
        chunk.file_import,
        {
          event: "chunk_completed",
          file_import_id: chunk.file_import_id,
          chunk_id: chunk.id,
          chunk_index: chunk.chunk_index,
          status: chunk.status,
          processed_rows: chunk.processed_rows,
          failed_rows: chunk.failed_rows,
          byte_size: chunk.byte_size,
        },
      )
    end

    def broadcast_import_finalized(file_import)
      broadcast_to(
        file_import,
        {
          event: "import_finalized",
          file_import_id: file_import.id,
          status: file_import.status,
          processed_rows: file_import.processed_rows,
          failed_rows: file_import.failed_rows,
          processed_bytes: file_import.processed_bytes,
          failed_bytes: file_import.failed_bytes,
        },
      )
    end
  end
end
