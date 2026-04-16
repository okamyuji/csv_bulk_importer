# frozen_string_literal: true

class CreateCsvImportChunks < ActiveRecord::Migration[8.1]
  def change
    create_table :csv_import_chunks do |t|
      t.references :csv_import,     null: false, foreign_key: true
      t.integer    :chunk_index,    null: false
      t.integer    :start_row,      null: false
      t.integer    :end_row,        null: false
      t.string     :status,         null: false, default: "pending"
      t.integer    :processed_rows, null: false, default: 0
      t.integer    :failed_rows,    null: false, default: 0
      t.json       :error_details
      t.integer    :retry_count,    null: false, default: 0
      t.string     :s3_key,         null: false
      t.integer    :lock_version,   null: false, default: 0

      t.timestamps
    end

    add_index :csv_import_chunks, %i[csv_import_id chunk_index], unique: true
    add_index :csv_import_chunks, :status
  end
end
