module Infrastructure
  module Persistence
    module ActiveRecord
      class ClientRecord < ::ApplicationRecord
        self.table_name = 'clients'
  has_secure_password validations: false

        validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
        validates :first_name, :last_name, :date_of_birth, presence: true
        validates :status, inclusion: { in: %w[pending active suspended rejected] }

        before_create :set_defaults

        private

        def set_defaults
          self.status ||= 'pending'
        end
      end
    end
  end
end
