# typed: true
# frozen_string_literal: true

module Api
  module V1
    class RegistrationsController < ActionController::API
      before_action :set_audit_context

      def create
        user = User.new(sign_up_params)

        unless user.valid?
          # full_messagesは「Email 'foo@bar.com' has already been taken」のように
          # ユーザー入力をそのまま含めるためAuditLoggerには流さない。
          # 失敗の原因はattribute_namesだけでも運用上十分。
          AuditLogger.event("auth.sign_up_failure", reasons: user.errors.attribute_names.first(3))
          render json: { error: "invalid", details: user.errors.full_messages }, status: :unprocessable_entity
          return
        end

        token =
          ActiveRecord::Base.transaction do
            user.save!
            issue_token(user) || raise(TokenIssuanceError, "JWT encoder returned nil token")
          end

        Current.user_id = user.id
        AuditLogger.event("auth.sign_up", provider: "password")
        response.set_header("Authorization", "Bearer #{token}")
        render json: { user: { id: user.id, email: user.email, name: user.name }, token: token }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        # 並列リクエストでメールユニーク制約違反など、validateを通った後にDBで弾かれた場合の保険。
        AuditLogger.event("auth.sign_up_failure", reasons: e.record.errors.attribute_names.first(3))
        render json: { error: "invalid", details: e.record.errors.full_messages }, status: :unprocessable_entity
      rescue TokenIssuanceError, JWT::EncodeError, Warden::NotAuthenticated => e
        # トークン発行に失敗した場合、トランザクションがロールバックされてユーザーレコードは
        # 残らない。クライアントは同じメールで再試行できる。
        AuditLogger.event("auth.sign_up_failure", reasons: ["token_issuance_failed"], error_class: e.class.name)
        render json: { error: "service_unavailable" }, status: :service_unavailable
      end

      private

      class TokenIssuanceError < StandardError
      end

      def issue_token(user)
        Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
      end

      def set_audit_context
        Current.request_id = request.request_id
      end

      def sign_up_params
        params.expect(user: %i[email password password_confirmation name])
      end
    end
  end
end
