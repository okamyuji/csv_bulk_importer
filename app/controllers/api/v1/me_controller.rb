# typed: true
# frozen_string_literal: true

module Api
  module V1
    class MeController < Api::BaseController
      def show
        user = T.must(current_user)
        render json: { id: user.id, email: user.email, name: user.name }
      end
    end
  end
end
