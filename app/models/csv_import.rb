# typed: true
# frozen_string_literal: true

class CsvImport < ApplicationRecord
  TARGET_KINDS = %w[sales_record ledger_entry].freeze
  STATUSES = %w[pending splitting processing completed completed_with_errors partially_failed failed].freeze

  belongs_to :user
  has_many :csv_import_chunks, dependent: :destroy
  has_many :sales_records, dependent: :nullify
  has_many :ledger_entries, dependent: :nullify
  has_one_attached :source_file

  validates :file_name, presence: true
  validates :target_kind, inclusion: { in: TARGET_KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :idempotency_key, presence: true, uniqueness: true

  scope :recent, -> { order(created_at: :desc) }

  def completed?
    %w[completed completed_with_errors partially_failed failed].include?(status)
  end

  def s3_prefix_or_default
    s3_prefix.presence || "csv_imports/#{id}"
  end

  # remaining_chunksをアトミックに1減らし、自分の呼び出しでカウンタが
  # 0に到達した場合だけtrueを返す。CsvChunkJobから呼び出して、
  # CsvImportFinalizerJobをチャンクごとではなくインポートあたり1回だけ
  # 起動するために使う。
  #
  # 行ロックで並行デクリメントを直列化するため、at-least-once配信下でも
  # 「0を観測した」と判断するのは必ず1人のワーカーだけになる。
  def finish_one_chunk!
    with_lock do
      next false if remaining_chunks <= 0

      decrement!(:remaining_chunks)
      remaining_chunks.zero?
    end
  end
end
