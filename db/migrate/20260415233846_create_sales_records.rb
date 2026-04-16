# frozen_string_literal: true

class CreateSalesRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :sales_records do |t|
      t.references :csv_import,      null: false, foreign_key: true
      t.date       :recorded_on,     null: false
      t.string     :customer_code,   null: false, limit: 32
      t.string     :product_code,    null: false, limit: 32
      t.integer    :quantity,        null: false
      t.decimal    :unit_price,      null: false, precision: 12, scale: 2
      t.decimal    :amount,          null: false, precision: 14, scale: 2
      t.string     :memo,            limit: 255
      t.string     :idempotency_key, null: false

      t.timestamps
    end

    add_index :sales_records, :idempotency_key, unique: true
    add_index :sales_records, %i[recorded_on customer_code]
  end
end
