# typed: true
# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Pundit::Authorization

  allow_browser versions: :modern

  before_action :set_audit_context

  rescue_from Pundit::NotAuthorizedError do |exception|
    AuditLogger.event(
      "authz.forbidden",
      policy: exception.policy.class.name,
      query: exception.query,
      target_type: exception.record.class.name,
      target_id: exception.record.respond_to?(:id) ? exception.record.id : nil,
    )
    render json: { error: "forbidden" }, status: :forbidden
  end

  private

  def set_audit_context
    Current.request_id = request.request_id
    Current.user_id = (respond_to?(:current_user, true) && current_user&.id) || nil
  end
end
