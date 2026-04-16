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
end
