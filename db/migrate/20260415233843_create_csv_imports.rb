# frozen_string_literal: true

class CreateCsvImports < ActiveRecord::Migration[8.1]
  def change
    create_table :csv_imports do |t|
      t.references :user, null: false, foreign_key: true
      t.string     :file_name,       null: false
      t.string     :target_kind,     null: false
      t.string     :status,          null: false, default: "pending"
      t.integer    :total_rows,      null: false, default: 0
      t.integer    :processed_rows,  null: false, default: 0
      t.integer    :failed_rows,     null: false, default: 0
      t.integer    :total_chunks,    null: false, default: 0
      t.string     :idempotency_key, null: false
      t.text       :error_message
      t.string     :s3_prefix

      t.timestamps
    end

    add_index :csv_imports, :idempotency_key, unique: true
    add_index :csv_imports, %i[user_id created_at]
    add_index :csv_imports, :status
  end
end
