# frozen_string_literal: true

require "rails_helper"

RSpec.describe CsvChunkJob, "finalizer enqueue rules" do
  let(:user) { create(:user) }
  let(:s3_prefix) { "file_imports/finalizer-spec" }

  let(:file_import) do
    create(
      :file_import,
      user: user,
      target_kind: "sales_record",
      status: "processing",
      s3_prefix: s3_prefix,
      total_chunks: 3,
      remaining_chunks: 3,
    )
  end

  let(:csv_body) do
    "recorded_on,customer_code,product_code,quantity,unit_price,amount,memo\n" \
      "2026-04-01,C001,P001,2,100.50,201.00,ok1\n"
  end

  def make_chunk(index)
    chunk =
      file_import.file_import_chunks.create!(
        chunk_index: index,
        start_row: index + 1,
        end_row: index + 1,
        status: "pending",
        s3_key: "#{s3_prefix}/chunk_#{format("%06d", index)}.csv",
      )
    AppS3.client.put_object(bucket: AppS3.bucket, key: chunk.s3_key, body: csv_body)
    chunk
  end

  it "enqueues FileImportFinalizerJob exactly once when the last chunk completes" do
    chunks = 3.times.map { |i| make_chunk(i) }

    expect do
      described_class.perform_now(chunks[0].id)
      described_class.perform_now(chunks[1].id)
    end.not_to(have_enqueued_job(FileImportFinalizerJob))

    expect { described_class.perform_now(chunks[2].id) }.to have_enqueued_job(FileImportFinalizerJob).with(
      file_import.id,
    ).exactly(:once)

    expect(file_import.reload.remaining_chunks).to eq(0)
  end

  it "only the final caller sees zero across re-deliveries (idempotent)" do
    chunks = 3.times.map { |i| make_chunk(i) }
    chunks.each { |c| described_class.perform_now(c.id) }
    expect(file_import.reload.remaining_chunks).to eq(0)

    # Solid Queueのat-least-once再配信: すでに完了したチャンクを
    # 再実行しても、カウンタを再度デクリメントしたりFinalizerを再enqueueしない。
    expect { described_class.perform_now(chunks[0].id) }.not_to(have_enqueued_job(FileImportFinalizerJob))
    expect(file_import.reload.remaining_chunks).to eq(0)
  end
end
