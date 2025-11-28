# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_client_id

    def connect
      self.current_client_id = find_verified_client
    end

    private

    def find_verified_client
      token = request.params[:token]
      
      if token.present?
        decoded = JwtService.decode(token)
        decoded['client_id']
      else
        reject_unauthorized_connection
      end
    rescue JWT::DecodeError => e
      Rails.logger.warn("[CABLE] Connection rejected: #{e.message}")
      reject_unauthorized_connection
    end
  end
end
