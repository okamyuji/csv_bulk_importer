# typed: true
# frozen_string_literal: true

class CsvImportChunk < ApplicationRecord
  STATUSES = %w[pending processing completed completed_with_errors failed].freeze

  belongs_to :csv_import

  validates :chunk_index, presence: true, uniqueness: { scope: :csv_import_id }
  validates :start_row, :end_row, presence: true, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: STATUSES }
  validates :s3_key, presence: true

  scope :pending_status, -> { where(status: "pending") }
  scope :failed_status, -> { where(status: "failed") }
  scope :in_progress, -> { where(status: %w[pending processing]) }

  def completed?
    %w[completed completed_with_errors].include?(status)
  end

  def final?
    %w[completed completed_with_errors failed].include?(status)
  end
end
