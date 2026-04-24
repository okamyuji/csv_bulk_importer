# frozen_string_literal: true

# CSVインポートのパイプライン全体（分割→チャンクジョブ→Finalizer）を
# 指定行数のCSVで計測する。Solid Queueワーカーは介さずinlineで動かすため、
# 計測値はキューのpollingコストではなくパイプライン自体のコストになる。
#
# 使い方:
#   bundle exec rake "csv_import:benchmark[100000]"
#   bundle exec rake "csv_import:benchmark[1000000]"
#
#   # 当初設計（Finalizerをチャンクごとに呼ぶ／perform_laterを個別呼び出し）を再現する
#   BENCH_MODE=legacy bundle exec rake "csv_import:benchmark[100000]"
#
# 前提: MySQL（development DB）+ LocalStack S3（docker compose up）。
namespace :csv_import do
  desc "Benchmark CsvImportJob end-to-end with N synthetic rows"
  task :benchmark, [:rows] => :environment do |_t, args|
    rows = Integer(args[:rows] || 100_000)
    abort("Rails.env=#{Rails.env}: only run benchmarks in development/test") if Rails.env.production?

    require "benchmark"
    require "csv"
    require "fileutils"

    # ジョブをこのプロセス内で同期実行する。Solid Queueのpollingではなく
    # パイプライン自体のコストを計測するため。
    ActiveJob::Base.queue_adapter = :inline

    user =
      User.find_or_create_by!(email: "bench@example.com") do |u|
        u.name = "bench"
        u.password = "benchpass1"
        u.password_confirmation = "benchpass1"
      end

    Rails.logger.level = Logger::WARN
    ActiveRecord::Base.logger.level = Logger::WARN if ActiveRecord::Base.logger

    tmp_path = Rails.root.join("tmp/bench_#{rows}.csv")
    generate_csv(tmp_path, rows)

    csv_import =
      CsvImport.create!(
        user: user,
        file_name: tmp_path.basename.to_s,
        target_kind: "sales_record",
        status: "pending",
        idempotency_key: "bench-#{rows}-#{Time.current.to_f}-#{SecureRandom.hex(4)}",
      )
    csv_import.source_file.attach(io: File.open(tmp_path), filename: tmp_path.basename.to_s, content_type: "text/csv")

    legacy_mode = ENV["BENCH_MODE"] == "legacy"

    if legacy_mode
      # 当初設計の「チャンクごとにFinalizerを呼ぶ／perform_laterを個別に呼ぶ」
      # 挙動を再現する。同じハードウェア・環境でbulk enqueue + Finalizer
      # 1回化と比較するため。本番コードはそのままで、このrakeタスク内だけで
      # オーバーライドする。
      CsvImport.class_eval { define_method(:finish_one_chunk!) { true } }
      legacy_bulk_patch =
        Module.new do
          def perform_all_later(jobs)
            jobs.each { |j| j.class.perform_later(*j.arguments) }
            jobs
          end
        end
      ActiveJob.singleton_class.prepend(legacy_bulk_patch)
    end

    rss_before = current_rss_mb

    # bulk enqueue APIに直接prependしてカウンタを取る。inline adapterでは
    # perform_all_laterの通知が安定しないため、呼び出し箇所そのものを
    # 観測する方が確実。
    bulk_spy =
      Module.new do
        def perform_all_later(jobs)
          if jobs.first.is_a?(CsvChunkJob)
            Thread.current[:bench_bulk_calls] = (Thread.current[:bench_bulk_calls] || 0) + 1
          end
          super
        end
      end
    finalizer_spy =
      Module.new do
        def perform_later(*args, **kwargs)
          Thread.current[:bench_finalizer_calls] = (Thread.current[:bench_finalizer_calls] || 0) + 1
          super
        end
      end
    chunk_perform_later_spy =
      Module.new do
        def perform_later(*args, **kwargs)
          Thread.current[:bench_chunk_perform_later_calls] = (Thread.current[:bench_chunk_perform_later_calls] || 0) + 1
          super
        end
      end

    Thread.current[:bench_bulk_calls] = 0
    Thread.current[:bench_finalizer_calls] = 0
    Thread.current[:bench_chunk_perform_later_calls] = 0

    ActiveJob.singleton_class.prepend(bulk_spy)
    CsvImportFinalizerJob.singleton_class.prepend(finalizer_spy)
    CsvChunkJob.singleton_class.prepend(chunk_perform_later_spy)

    elapsed = Benchmark.realtime { CsvImportJob.perform_now(csv_import.id) }

    bulk_enqueue_calls = Thread.current[:bench_bulk_calls].to_i
    finalizer_enqueue_calls = Thread.current[:bench_finalizer_calls].to_i
    chunk_perform_later_calls = Thread.current[:bench_chunk_perform_later_calls].to_i

    rss_after = current_rss_mb
    csv_import.reload

    puts ""
    puts "=== CSV import benchmark ==="
    puts "mode                       : #{legacy_mode ? "legacy" : "current"}"
    puts "rows                       : #{rows}"
    puts "total_chunks               : #{csv_import.total_chunks}"
    puts "elapsed (seconds)          : #{elapsed.round(2)}"
    puts "throughput (rows/sec)      : #{(rows / elapsed).round}"
    puts "rss before / after MB      : #{rss_before} / #{rss_after} (delta +#{rss_after - rss_before})"
    puts "ActiveJob.perform_all_later: #{bulk_enqueue_calls}"
    puts "CsvChunkJob.perform_later  : #{chunk_perform_later_calls}"
    puts "finalizer enqueues         : #{finalizer_enqueue_calls}"
    puts "final status               : #{csv_import.status}"
    puts "processed / failed         : #{csv_import.processed_rows} / #{csv_import.failed_rows}"
  ensure
    FileUtils.rm_f(tmp_path) if defined?(tmp_path) && tmp_path
  end
end

# 指定行数の正常なsales-record CSVを生成する。rakeタスク自身が
# ファイル全体をメモリに展開しないよう、ストリームIOで書き出す。
def generate_csv(path, rows)
  File.open(path, "w") do |f|
    f.puts "recorded_on,customer_code,product_code,quantity,unit_price,amount,memo"
    base = Date.parse("2026-01-01")
    rows.times do |i|
      day = base + (i % 365)
      cust = format("C%05d", i % 1_000)
      prod = format("P%05d", i % 200)
      qty = (i % 9) + 1
      price = 100 + (i % 50)
      amount = qty * price
      f.puts "#{day},#{cust},#{prod},#{qty},#{price}.00,#{amount}.00,row#{i}"
    end
  end
end

def current_rss_mb
  rss_kb =
    if RUBY_PLATFORM.include?("darwin")
      `ps -o rss= -p #{Process.pid}`.to_i
    else
      File.read("/proc/#{Process.pid}/status").match(/VmRSS:\s+(\d+)/)[1].to_i
    end
  (rss_kb / 1024.0).round
end
