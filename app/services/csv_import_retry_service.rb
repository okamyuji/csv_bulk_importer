# typed: true
# frozen_string_literal: true

class CsvImportRetryService
  Result = Data.define(:retried, :chunk_ids)

  class << self
    def call(csv_import)
      failed = csv_import.csv_import_chunks.where(status: "failed").order(:chunk_index)
      return Result.new(retried: 0, chunk_ids: []) if failed.empty?

      chunk_ids = []

      CsvImport.transaction do
        csv_import.update!(status: "processing", error_message: nil)

        failed.each do |chunk|
          chunk.update!(status: "pending", retry_count: chunk.retry_count + 1, error_details: nil)
          chunk_ids << chunk.id
        end
      end

      # Enqueue outside the transaction so the DB state is visible to the worker.
      chunk_ids.each { |cid| CsvChunkJob.perform_later(cid) }

      Result.new(retried: chunk_ids.size, chunk_ids: chunk_ids)
    end
  end
end
