# typed: true
# frozen_string_literal: true

class CsvImportChunkResource
  include Alba::Resource

  attributes :id,
             :csv_import_id,
             :chunk_index,
             :start_row,
             :end_row,
             :status,
             :processed_rows,
             :failed_rows,
             :retry_count,
             :error_details,
             :created_at,
             :updated_at
end
