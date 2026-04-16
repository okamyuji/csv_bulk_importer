# frozen_string_literal: true

class CreateLedgerEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :ledger_entries do |t|
      t.references :csv_import,      null: false, foreign_key: true
      t.date       :posted_on,       null: false
      t.string     :account_code,    null: false, limit: 16
      t.decimal    :debit,           null: false, precision: 14, scale: 2, default: 0
      t.decimal    :credit,          null: false, precision: 14, scale: 2, default: 0
      t.string     :description,     limit: 255
      t.string     :idempotency_key, null: false

      t.timestamps
    end

    add_index :ledger_entries, :idempotency_key, unique: true
    add_index :ledger_entries, %i[posted_on account_code]
  end
end
