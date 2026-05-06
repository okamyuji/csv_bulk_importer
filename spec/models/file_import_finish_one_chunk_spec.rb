# frozen_string_literal: true

require "rails_helper"

RSpec.describe FileImport, "#finish_one_chunk!" do
  let(:user) { create(:user) }

  it "decrements remaining_chunks and returns false until the last call" do
    file_import = create(:file_import, user: user, remaining_chunks: 3)

    expect(file_import.finish_one_chunk!).to be false
    expect(file_import.reload.remaining_chunks).to eq(2)

    expect(file_import.finish_one_chunk!).to be false
    expect(file_import.reload.remaining_chunks).to eq(1)

    expect(file_import.finish_one_chunk!).to be true
    expect(file_import.reload.remaining_chunks).to eq(0)
  end

  it "returns false and does not go negative once the counter is exhausted" do
    file_import = create(:file_import, user: user, remaining_chunks: 0)

    expect(file_import.finish_one_chunk!).to be false
    expect(file_import.reload.remaining_chunks).to eq(0)
  end

  it "returns true exactly once across the full sequence of completions" do
    # 本番での並行性は親行に対するwith_lock（SELECT ... FOR UPDATE）で
    # 担保している。RSpecのトランザクションフィクスチャはスレッド間で
    # 互いに見えないため、ここでは逐次呼び出しの不変条件だけ確認し、
    # ロックの意味はインテグレーションで検証する。
    file_import = create(:file_import, user: user, remaining_chunks: 5)

    results = Array.new(5) { FileImport.find(file_import.id).finish_one_chunk! }

    expect(results.count(true)).to eq(1)
    expect(results.last).to be true
    expect(file_import.reload.remaining_chunks).to eq(0)
  end
end
