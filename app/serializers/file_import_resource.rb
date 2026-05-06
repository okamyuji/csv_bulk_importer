# typed: true
# frozen_string_literal: true

class FileImportResource
  include Alba::Resource

  attributes :id,
             :file_name,
             :input_kind,
             :target_kind,
             :content_type,
             :byte_size,
             :status,
             :total_rows,
             :processed_rows,
             :failed_rows,
             :total_bytes,
             :processed_bytes,
             :failed_bytes,
             :total_chunks,
             :idempotency_key,
             :source_checksum,
             :reassembled_s3_key,
             :reassembled_checksum,
             :error_message,
             :created_at,
             :updated_at

  attribute :progress do |imp|
    denominator = imp.progress_denominator.to_i
    next 0 if denominator.zero?

    (imp.progress_numerator.to_f / denominator * 100).round(1)
  end

  # ユーザに見せるためのフレンドリ名。reassembled_s3_keyは決定的キー
  # （reassembled-<id>.bin）でファイル命名規則を漏らさないが、UIで生のキーよりも
  # 元ファイル名を見せたいケースが多いので別フィールドで提供する。
  attribute :reassembled_display_name do |imp|
    next nil if imp.reassembled_s3_key.blank?

    imp.file_name.presence || "reassembled-#{imp.id}.bin"
  end
end
