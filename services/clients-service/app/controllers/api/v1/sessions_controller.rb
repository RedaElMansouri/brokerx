# frozen_string_literal: true

module Api
  module V1
    class SessionsController < ApplicationController
      before_action :authenticate_client!

      # GET /api/v1/me
      def show
        render json: ClientSerializer.new(current_client).as_json
      end
    end
  end
end
