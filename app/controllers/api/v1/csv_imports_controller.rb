# typed: true
# frozen_string_literal: true

require "digest"

module Api
  module V1
    class CsvImportsController < Api::BaseController
      def index
        scope = policy_scope(CsvImport).recent.limit(100)
        render json: { data: CsvImportResource.new(scope).serializable_hash }
      end

      def show
        imp = CsvImport.find(params[:id])
        authorize imp
        render json: {
                 data: CsvImportResource.new(imp).serializable_hash,
                 chunks: CsvImportChunkResource.new(imp.csv_import_chunks.order(:chunk_index)).serializable_hash,
               }
      end

      def create
        authorize CsvImport, :create?

        file = params.require(:file)
        target_kind = params.require(:target_kind)

        unless CsvImport::TARGET_KINDS.include?(target_kind)
          return render json: { error: "invalid target_kind" }, status: :unprocessable_entity
        end

        imp =
          CsvImport.create!(
            user: current_user,
            file_name: file.original_filename,
            target_kind: target_kind,
            status: "pending",
            idempotency_key: build_idempotency_key(file),
          )
        imp.source_file.attach(
          io: file.tempfile.open,
          filename: file.original_filename,
          content_type: file.content_type || "text/csv",
        )
        imp.update!(s3_prefix: "csv_imports/#{imp.id}")

        Current.csv_import_id = imp.id
        AuditLogger.event(
          "csv_import.created",
          file_name: file.original_filename,
          byte_size: file.size,
          target_kind: target_kind,
          idempotency_prefix: imp.idempotency_key[0, 12],
        )

        CsvImportJob.perform_later(imp.id)

        render json: { data: CsvImportResource.new(imp).serializable_hash }, status: :accepted
      end

      def retry
        imp = CsvImport.find(params[:id])
        authorize imp, :retry?
        Current.csv_import_id = imp.id
        result = CsvImportRetryService.call(imp)
        AuditLogger.event("csv_import.retried", retried_chunks: result.retried)
        render json: { retried: result.retried }, status: :accepted
      end

      private

      def build_idempotency_key(file)
        # 秒単位だと同一秒内の再送で衝突し得るため、マイクロ秒（%s%6N）まで含めて
        # 衝突確率を下げる。プラットフォーム依存の Time#to_f ではなく、明示フォーマットを使う
        user = T.must(current_user)
        timestamp = Time.current.strftime("%s%6N")
        Digest::SHA256.hexdigest("#{user.id}|#{file.original_filename}|#{file.size}|#{timestamp}")
      end
    end
  end
end
