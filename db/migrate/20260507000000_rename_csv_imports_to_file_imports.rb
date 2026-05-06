# frozen_string_literal: true

# CSV専用だった頃の名残でcsv_imports / csv_import_chunks というテーブル名と
# csv_import_id というFKだったが、現在はバイナリ取り込みも同じテーブルで
# 扱うため、中立的なfile_imports / file_import_chunks / file_import_id に改名する。
class RenameCsvImportsToFileImports < ActiveRecord::Migration[8.1]
  def change
    rename_table :csv_imports, :file_imports
    rename_table :csv_import_chunks, :file_import_chunks

    rename_column :file_import_chunks, :csv_import_id, :file_import_id
    rename_column :sales_records, :csv_import_id, :file_import_id
    rename_column :ledger_entries, :csv_import_id, :file_import_id
    rename_column :binary_assets, :csv_import_id, :file_import_id
  end
end
