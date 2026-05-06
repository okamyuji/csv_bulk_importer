# typed: true
# frozen_string_literal: true

class FileImportRetryService
  Result = Data.define(:retried, :chunk_ids)

  class << self
    def call(file_import)
      failed = file_import.file_import_chunks.where(status: "failed").order(:chunk_index)
      return Result.new(retried: 0, chunk_ids: []) if failed.empty?

      chunk_ids = []

      FileImport.transaction do
        # 再投入する分だけremaining_chunksを加算し、再開チャンクが完了した
        # 時点でfinish_one_chunk!が0を観測してFinalizerを1回起動できるようにする
        file_import.update!(
          status: "processing",
          error_message: nil,
          remaining_chunks: file_import.remaining_chunks + failed.size,
        )

        failed.each do |chunk|
          chunk.update!(status: "pending", retry_count: chunk.retry_count + 1, error_details: nil)
          chunk_ids << chunk.id
        end
      end

      # ワーカーがDB状態を見られるようトランザクションの外でenqueueする
      chunks = FileImportChunk.includes(:file_import).where(id: chunk_ids).order(:chunk_index)
      ActiveJob.perform_all_later(chunks.map { |chunk| ImportChunkJobFactory.build(chunk) })

      Result.new(retried: chunk_ids.size, chunk_ids: chunk_ids)
    end
  end
end
