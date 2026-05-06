# typed: true
# frozen_string_literal: true

class FileImportJob < ApplicationJob
  queue_as :file_import

  def perform(file_import_id)
    file_import = FileImport.find(file_import_id)
    Current.file_import_id = file_import.id
    Current.user_id = file_import.user_id
    return unless %w[pending failed].include?(file_import.status)

    file_import.update!(status: "splitting", error_message: nil, s3_prefix: file_import.s3_prefix_or_default)
    AuditLogger.event("file_import.splitting_started")

    result =
      ImportSourceOpener.call(file_import) do |io|
        ImportSplitter.call(file_import: file_import, io: io, bucket: AppS3.bucket, s3_client: AppS3.client)
      end

    FileImport.transaction do
      file_import.update!(processing_attributes(file_import, result))

      result.chunks.each { |c| file_import.file_import_chunks.create!(chunk_attributes(file_import, c)) }
    end

    broadcast_split_started(file_import)

    # チャンクジョブをbulk enqueueし、Solid QueueへのINSERTを
    # 1ラウンドトリップにまとめる。
    chunks = file_import.file_import_chunks.includes(:file_import).order(:chunk_index)
    ActiveJob.perform_all_later(chunks.map { |chunk| ImportChunkJobFactory.build(chunk) })
  rescue StandardError => e
    FileImport.where(id: file_import_id).update_all(status: "failed", error_message: e.message)
    AuditLogger.event("file_import.splitting_failed", error_class: e.class.name, error_message: e.message[0, 200])
    raise
  end

  private

  def processing_attributes(file_import, result)
    attrs = {
      status: "processing",
      total_chunks: result.total_chunks,
      # 「未完了チャンク数」カウンタを総チャンク数で初期化する。
      # 最後のチャンク完了時にFinalizerを1回だけ起動するために使う
      # (FileImport#finish_one_chunk!を参照)
      remaining_chunks: result.total_chunks,
    }
    if file_import.binary?
      attrs[:total_bytes] = result.total_bytes
      attrs[:source_checksum] = result.source_checksum
    else
      attrs[:total_rows] = result.total_rows
    end
    attrs
  end

  def chunk_attributes(file_import, chunk)
    attrs = { chunk_index: chunk.index, status: "pending", s3_key: chunk.s3_key }
    if file_import.binary?
      attrs.merge!(start_byte: chunk.start_byte, end_byte: chunk.end_byte, byte_size: chunk.byte_size)
    else
      attrs.merge!(start_row: chunk.start_row, end_row: chunk.end_row)
    end
    attrs
  end

  def broadcast_split_started(file_import)
    FileImportChannel.broadcast_split_started(file_import)
    Rails.logger.info(
      "[FileImportJob] split_started file_import_id=#{file_import.id} input_kind=#{file_import.input_kind} chunks=#{file_import.total_chunks}",
    )
  end
end
