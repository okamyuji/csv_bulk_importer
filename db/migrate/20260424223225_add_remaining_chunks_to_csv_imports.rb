# frozen_string_literal: true

class AddRemainingChunksToCsvImports < ActiveRecord::Migration[8.1]
  def change
    add_column :csv_imports, :remaining_chunks, :integer, null: false, default: 0
  end
end
