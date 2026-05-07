# frozen_string_literal: true

# 使い方: ruby script/bench/gen_csv.rb <行数> <出力パス>
# 例:    ruby script/bench/gen_csv.rb 100000 tmp/bench/sales_100k.csv
#
# sales_record ターゲット用の合成 CSV を生成する。
# 全行が CsvRowMapper.map_sales を通る妥当データ。

require "date"
require "fileutils"

rows = Integer(ARGV[0])
out  = ARGV[1]
FileUtils.mkdir_p(File.dirname(out))

base = Date.new(2024, 1, 1)
File.open(out, "w") do |f|
  f.puts "recorded_on,customer_code,product_code,quantity,unit_price,amount,memo"
  rows.times do |i|
    d = base + (i % 365)
    cust = "C#{(i % 1000).to_s.rjust(4, '0')}"
    prod = "P#{(i % 500).to_s.rjust(4, '0')}"
    qty  = (i % 9) + 1
    price = 100 + (i % 90)
    amount = qty * price
    f.puts "#{d.iso8601},#{cust},#{prod},#{qty},#{price}.00,#{amount}.00,row#{i}"
  end
end
puts "rows=#{rows} bytes=#{File.size(out)} path=#{out}"
