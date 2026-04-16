# frozen_string_literal: true

require "rails_helper"

RSpec.describe CsvImportChannel, type: :channel do
  let(:owner) { create(:user) }
  let(:other) { create(:user) }
  let(:csv_import) { create(:csv_import, user: owner) }

  it "accepts the owner and streams for the csv_import" do
    stub_connection current_user: owner
    subscribe(csv_import_id: csv_import.id)
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_for(csv_import)
  end

  it "rejects a non-owner" do
    stub_connection current_user: other
    subscribe(csv_import_id: csv_import.id)
    expect(subscription).to be_rejected
  end

  it "rejects an unknown csv_import" do
    stub_connection current_user: owner
    subscribe(csv_import_id: 999_999)
    expect(subscription).to be_rejected
  end

  describe ".broadcast_chunk_completed" do
    let!(:chunk) do
      csv_import.csv_import_chunks.create!(
        chunk_index: 0,
        start_row: 1,
        end_row: 10,
        status: "completed",
        processed_rows: 10,
        failed_rows: 0,
        s3_key: "k0",
      )
    end

    it "broadcasts on the csv_import stream" do
      expect { described_class.broadcast_chunk_completed(chunk) }.to have_broadcasted_to(csv_import).from_channel(
        described_class,
      ).with(hash_including(event: "chunk_completed", chunk_id: chunk.id))
    end
  end
end
