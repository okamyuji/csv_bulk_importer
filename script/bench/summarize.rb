# frozen_string_literal: true
# 使い方: bin/rails runner script/bench/summarize.rb
#
# tmp/bench/results/result_<label>.txt と DB の最新 FileImport を突き合わせ、
# 「分割 / DB投入 / アップロード / メモリ増加」をまとめて出力する。

OUT_DIR = ENV.fetch("BENCH_OUT", "tmp/bench/results")

LABELS_TO_FILENAME = {
  "csv_100k"  => "sales_100k.csv",
  "csv_1m"    => "sales_1m.csv",
  "img_small" => "img_small.jpg",
  "img_large" => "img_large.jpg",
}

def parse_result(label)
  path = File.join(OUT_DIR, "result_#{label}.txt")
  return nil unless File.exist?(path)
  File.foreach(path).each_with_object({}) do |line, h|
    k, _, v = line.chomp.partition("=")
    h[k] = v
  end
end

def fmt_mb(kb) = (kb.to_i / 1024.0).round(1)

LABELS_TO_FILENAME.each do |label, filename|
  fi = FileImport.where(file_name: filename).order(id: :desc).first
  unless fi
    puts "==== #{label}: skipped (FileImport with file_name=#{filename} not found)"
    puts ""
    next
  end

  res = parse_result(label) || {}
  chunks = FileImportChunk.where(file_import_id: fi.id)
  first_chunk_at = chunks.minimum(:created_at)
  last_chunk_at  = chunks.maximum(:updated_at)
  split_seconds  = first_chunk_at ? (first_chunk_at - fi.created_at).to_f.round(3) : nil
  process_seconds = (first_chunk_at && last_chunk_at) ? (last_chunk_at - first_chunk_at).to_f.round(3) : nil
  total_e2e      = (fi.updated_at - fi.created_at).to_f.round(3)

  puts "==== #{label} (id=#{fi.id}) ===="
  puts "  status              : #{fi.status}"
  puts "  byte_size           : #{fi.byte_size}"
  puts "  total_chunks        : #{fi.total_chunks}"
  if fi.csv?
    puts "  total_rows          : #{fi.total_rows}"
    puts "  processed_rows      : #{fi.processed_rows}"
    puts "  failed_rows         : #{fi.failed_rows}"
  else
    puts "  total_bytes         : #{fi.total_bytes}"
    puts "  processed_bytes     : #{fi.processed_bytes}"
    puts "  failed_bytes        : #{fi.failed_bytes}"
    if (b = BinaryAsset.find_by(file_import_id: fi.id))
      puts "  binary_asset_status : #{b.status}"
      puts "  reassembled_key     : #{b.reassembled_s3_key}"
    end
  end
  puts "  upload_seconds      : #{res['upload_seconds']}"
  puts "  split_seconds       : #{split_seconds}"
  puts "  process_seconds     : #{process_seconds}"
  puts "  total_seconds       : #{total_e2e}"

  if res['worker_rss_before_kb']
    wb, wp, wa = res.values_at('worker_rss_before_kb', 'worker_rss_peak_kb', 'worker_rss_after_kb').map(&:to_i)
    pb, pp, pa = res.values_at('puma_rss_before_kb', 'puma_rss_peak_kb', 'puma_rss_after_kb').map(&:to_i)
    puts "  worker_rss          : before=#{fmt_mb(wb)}MB peak=#{fmt_mb(wp)}MB after=#{fmt_mb(wa)}MB delta_peak=+#{fmt_mb(wp - wb)}MB"
    puts "  puma_rss            : before=#{fmt_mb(pb)}MB peak=#{fmt_mb(pp)}MB after=#{fmt_mb(pa)}MB delta_peak=+#{fmt_mb(pp - pb)}MB"
  end

  if fi.csv? && process_seconds&.positive?
    puts "  throughput          : #{(fi.processed_rows / process_seconds).round(0)} rows/sec"
  elsif !fi.csv? && process_seconds&.positive?
    puts "  throughput          : #{(fi.byte_size / 1024.0 / 1024.0 / process_seconds).round(1)} MB/sec"
  end
  puts ""
end
