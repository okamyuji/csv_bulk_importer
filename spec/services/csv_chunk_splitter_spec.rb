# frozen_string_literal: true

require "rails_helper"

RSpec.describe CsvChunkSplitter do
  let(:fake) { FakeS3.new }

  def call(io, chunk_size: 500)
    described_class.call(io: io, s3_prefix: "csv_imports/99", bucket: "b", s3_client: fake, chunk_size: chunk_size)
  end

  it "splits 1250 rows into 3 chunks and preserves header in each chunk" do
    lines = ["h1,h2\n"] + (1..1250).map { |i| "v#{i},x\n" }
    result = call(StringIO.new(lines.join))

    expect(result.total_rows).to eq(1250)
    expect(result.total_chunks).to eq(3)
    expect(fake.keys.size).to eq(3)

    result.chunks.each do |c|
      body = fake.get_object(bucket: "b", key: c.s3_key).body.read
      expect(body.lines.first).to eq("h1,h2\n")
    end
  end

  it "fails on an empty file" do
    expect { call(StringIO.new("")) }.to raise_error(ArgumentError, /no header/)
  end

  it "produces a single chunk for an under-size file" do
    io = StringIO.new("h1\n" + (1..10).map { |i| "v#{i}\n" }.join)
    result = call(io, chunk_size: 500)
    expect(result.total_chunks).to eq(1)
    expect(result.total_rows).to eq(10)
  end

  it "skips blank lines" do
    io = StringIO.new("h1\na\n\nb\n\n")
    result = call(io)
    expect(result.total_rows).to eq(2)
  end
end
