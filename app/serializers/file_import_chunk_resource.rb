# typed: true
# frozen_string_literal: true

class FileImportChunkResource
  include Alba::Resource

  attributes :id,
             :file_import_id,
             :chunk_index,
             :start_row,
             :end_row,
             :start_byte,
             :end_byte,
             :byte_size,
             :checksum,
             :status,
             :processed_rows,
             :failed_rows,
             :retry_count,
             :error_details,
             :created_at,
             :updated_at
end
