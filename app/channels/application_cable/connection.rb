# typed: true
# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    extend T::Sig

    identified_by :current_user

    sig { returns(T.nilable(User)) }
    attr_accessor :current_user

    def connect
      self.current_user = find_verified_user || reject_unauthorized_connection
    end

    private

    sig { returns(T.nilable(User)) }
    def find_verified_user
      token = request.params[:token].presence || extract_bearer_token(request.headers["Authorization"])
      return nil if token.blank?

      payload = decode_jwt(token)
      return nil unless payload

      user = User.find_by(id: payload["sub"])
      return nil if user.nil?
      return nil if JwtDenylist.exists?(jti: payload["jti"])

      user
    end

    def extract_bearer_token(header)
      return nil if header.blank?

      header.sub(/^Bearer\s+/, "")
    end

    def decode_jwt(token)
      secret = ENV.fetch("DEVISE_JWT_SECRET_KEY") { Rails.application.secret_key_base }
      ::JWT.decode(token, secret, true, algorithm: "HS256").first
    rescue ::JWT::DecodeError
      nil
    end
  end
end
