# typed: true
# frozen_string_literal: true

class SpaController < ActionController::Base
  def index
    file = Rails.public_path.join("index.html")
    if file.exist?
      render file: file, layout: false, content_type: "text/html"
    else
      render plain: "SPA not built. Run: pnpm --dir frontend build", status: :service_unavailable
    end
  end
end
