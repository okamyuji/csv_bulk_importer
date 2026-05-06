# frozen_string_literal: true

require "rails_helper"

RSpec.describe FileImportChannel, type: :channel do
  let(:owner) { create(:user) }
  let(:other) { create(:user) }
  let(:file_import) { create(:file_import, user: owner) }

  it "accepts the owner and streams for the file_import" do
    stub_connection current_user: owner
    subscribe(file_import_id: file_import.id)
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_for(file_import)
  end

  it "rejects a non-owner" do
    stub_connection current_user: other
    subscribe(file_import_id: file_import.id)
    expect(subscription).to be_rejected
  end

  it "rejects an unknown file_import" do
    stub_connection current_user: owner
    subscribe(file_import_id: 999_999)
    expect(subscription).to be_rejected
  end

  describe ".broadcast_chunk_completed" do
    let!(:chunk) do
      file_import.file_import_chunks.create!(
        chunk_index: 0,
        start_row: 1,
        end_row: 10,
        status: "completed",
        processed_rows: 10,
        failed_rows: 0,
        s3_key: "k0",
      )
    end

    it "broadcasts on the file_import stream" do
      expect { described_class.broadcast_chunk_completed(chunk) }.to have_broadcasted_to(file_import).from_channel(
        described_class,
      ).with(hash_including(event: "chunk_completed", chunk_id: chunk.id))
    end
  end
end
