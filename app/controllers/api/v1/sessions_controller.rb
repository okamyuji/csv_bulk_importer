# typed: true
# frozen_string_literal: true

module Api
  module V1
    class SessionsController < Devise::SessionsController
      respond_to :json
      protect_from_forgery with: :null_session

      private

      def respond_with(resource, _opts = {})
        if resource.persisted?
          Current.user_id = resource.id
          AuditLogger.event("auth.sign_in_success", method: "password")
        else
          # full_messagesにはユーザー入力（メールアドレスなど）が混ざり得るので、
          # 監査ログには属性名のみ落としてPII漏洩を避ける。
          AuditLogger.event("auth.sign_in_failure", reasons: resource.errors.attribute_names.first(3))
        end

        render json: { user: user_payload(resource), token: request.env["warden-jwt_auth.token"] }, status: :ok
      end

      def respond_to_on_destroy(*)
        if request.headers["Authorization"].present?
          AuditLogger.event("auth.sign_out")
          head :no_content
        else
          head :unauthorized
        end
      end

      def user_payload(user)
        { id: user.id, email: user.email, name: user.name }
      end
    end
  end
end
