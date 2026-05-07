# typed: true
# frozen_string_literal: true

# Streams a CSV from an IO and uploads CHUNK_SIZE-row chunks to S3.
# Accepts any IO that responds to `gets` and `each_line`
# so callers can pass File, Tempfile, or StringIO.
class CsvChunkSplitter
  # 1チャンクあたりの行数。チャンク数が増えるほど Solid Queue ジョブの enqueue/poll
  # オーバーヘッドが支配的になり、500 行では 1M 行で 2,000 チャンクになって律速していた。
  # 2,000 行/チャンクに上げて 100 万行 → 500 チャンクに圧縮する。
  CHUNK_SIZE = 2000

  Chunk = Data.define(:index, :start_row, :end_row, :s3_key, :byte_size)
  Result = Data.define(:total_rows, :total_chunks, :chunks)

  class << self
    def call(io:, s3_prefix:, bucket:, s3_client:, chunk_size: CHUNK_SIZE)
      new(io, s3_prefix, bucket, s3_client, chunk_size).call
    end
  end

  def initialize(io, s3_prefix, bucket, s3_client, chunk_size)
    @io = io
    @s3_prefix = s3_prefix
    @bucket = bucket
    @s3_client = s3_client
    @chunk_size = chunk_size
  end

  def call
    header = @io.gets
    raise ArgumentError, "CSV is empty or has no header" if header.nil? || header.strip.empty?

    buffer = []
    row_number = 0
    chunks = []
    chunk_index = 0

    @io.each_line do |line|
      next if line.strip.empty?

      row_number += 1
      buffer << line
      next if buffer.size < @chunk_size

      chunks << flush_chunk(header, buffer, chunk_index, row_number)
      chunk_index += 1
      buffer = []
    end

    if buffer.any?
      chunks << flush_chunk(header, buffer, chunk_index, row_number)
      chunk_index += 1
    end

    Result.new(total_rows: row_number, total_chunks: chunk_index, chunks: chunks)
  end

  private

  def flush_chunk(header, buffer, chunk_index, end_row)
    key = "#{@s3_prefix}/chunk_#{chunk_index.to_s.rjust(6, "0")}.csv"
    body = String.new(header)
    buffer.each { |line| body << line }

    @s3_client.put_object(bucket: @bucket, key: key, body: body)

    Chunk.new(
      index: chunk_index,
      start_row: end_row - buffer.size + 1,
      end_row: end_row,
      s3_key: key,
      byte_size: body.bytesize,
    )
  end
end
