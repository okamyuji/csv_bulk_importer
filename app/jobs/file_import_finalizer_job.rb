# typed: true
# frozen_string_literal: true

class FileImportFinalizerJob < ApplicationJob
  queue_as :file_import

  def perform(file_import_id)
    file_import = FileImport.find(file_import_id)
    chunks = file_import.file_import_chunks
    return if chunks.where(status: %w[pending processing]).exists?

    Current.file_import_id = file_import.id
    Current.user_id = file_import.user_id

    if file_import.binary?
      finalize_binary_import(file_import, chunks)
    else
      finalize_file_import(file_import, chunks)
    end

    FileImportChannel.broadcast_import_finalized(file_import)
  end

  private

  def finalize_file_import(file_import, chunks)
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

    file_import.update!(status: new_status, processed_rows: total_processed, failed_rows: total_failed)

    AuditLogger.event(
      "file_import.finalized",
      status: new_status,
      total_rows: file_import.total_rows,
      processed_rows: total_processed,
      failed_rows: total_failed,
      failed_chunks: failed_chunks,
    )
  end

  def finalize_binary_import(file_import, chunks)
    return if file_import.status == "completed" && file_import.binary_asset&.status == "completed"

    failed_chunks = chunks.where(status: "failed").count
    total_processed = chunks.where(status: %w[completed completed_with_errors]).sum(:byte_size)
    total_failed = chunks.where(status: "failed").sum(:byte_size)

    if failed_chunks.positive?
      new_status = total_processed.zero? ? "failed" : "partially_failed"
      file_import.update!(status: new_status, processed_bytes: total_processed, failed_bytes: total_failed)
      upsert_binary_asset(file_import, new_status)
      audit_binary_finalized(file_import, new_status, failed_chunks)
      return
    end

    result = reassemble_binary_import!(file_import)
    file_import.update!(
      status: "completed",
      processed_bytes: total_processed,
      failed_bytes: 0,
      reassembled_s3_key: result.s3_key,
      reassembled_checksum: result.checksum,
    )
    upsert_binary_asset(file_import, "completed")
    audit_binary_finalized(file_import, "completed", 0)
  end

  def reassemble_binary_import!(file_import)
    BinaryFileReassembler.call(file_import: file_import, bucket: AppS3.bucket, s3_client: AppS3.client)
  rescue StandardError => e
    file_import.update!(status: "failed", error_message: e.message)
    upsert_binary_asset(file_import, "failed")
    AuditLogger.event("binary_import.reassemble_failed", error_class: e.class.name, error_message: e.message[0, 200])
    raise
  end

  def upsert_binary_asset(file_import, status)
    # find_or_initialize_by + save! は同時 finalizer 実行下で TOCTOU 競合し、
    # 両方が「無し」と判定 → 両方が save! → idempotency_key の unique 制約違反で
    # 片方が ActiveRecord::RecordNotUnique になる。
    # idempotency_key の unique index に依存して、初回は新規作成、再実行は既存行更新に振り分ける。
    # ActiveRecord::RecordNotUnique を 1 度だけ retry することで、競合相手の commit を
    # 待ってから既存行を update する。
    attrs = binary_asset_attributes(file_import, status)
    attempts = 0
    begin
      asset = BinaryAsset.find_by(idempotency_key: file_import.idempotency_key)
      if asset.nil?
        BinaryAsset.create!(attrs.merge(file_import: file_import, idempotency_key: file_import.idempotency_key))
      else
        asset.update!(attrs)
      end
    rescue ActiveRecord::RecordNotUnique
      attempts += 1
      retry if attempts < 2

      raise
    end
  end

  def binary_asset_attributes(file_import, status)
    {
      file_name: file_import.file_name,
      content_type: file_import.content_type || "application/octet-stream",
      byte_size: file_import.byte_size,
      checksum: checksum_for_binary_asset(file_import),
      reassembled_s3_key: file_import.reassembled_s3_key,
      reassembled_checksum: file_import.reassembled_checksum,
      status: status,
      metadata: {
        input_kind: file_import.input_kind,
      },
    }
  end

  def checksum_for_binary_asset(file_import)
    file_import.source_checksum.presence || file_import.reassembled_checksum.presence ||
      raise(ArgumentError, "missing binary checksum")
  end

  def audit_binary_finalized(file_import, status, failed_chunks)
    AuditLogger.event(
      "binary_import.finalized",
      status: status,
      total_bytes: file_import.total_bytes,
      processed_bytes: file_import.processed_bytes,
      failed_bytes: file_import.failed_bytes,
      failed_chunks: failed_chunks,
    )
  end
end
