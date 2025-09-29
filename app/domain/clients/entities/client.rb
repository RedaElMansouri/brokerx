module Domain
  module Clients
    module Entities
      class Client < Domain::Shared::Entity
        attr_reader :email, :first_name, :last_name, :date_of_birth, :status,
                    :verification_token, :verified_at

        def initialize(
          email:,
          first_name:,
          last_name:,
          date_of_birth:,
          status: :pending,
          verification_token: nil,
          verified_at: nil,
          **kwargs
        )
          super(**kwargs)
          @email = email.is_a?(ValueObjects::Email) ? email : ValueObjects::Email.new(email)
          @first_name = first_name
          @last_name = last_name
          @date_of_birth = date_of_birth
          @status = status.to_sym
          @verification_token = verification_token
          @verified_at = verified_at

          validate!
        end

        def activate!(verification_token)
          raise "Invalid verification token" unless @verification_token == verification_token
          raise "Client already active" if active?

          @status = :active
          @verified_at = Time.current
          @verification_token = nil
          touch
        end

        def active?
          status == :active
        end

        def pending?
          status == :pending
        end

        def full_name
          "#{first_name} #{last_name}"
        end

        def age
          return nil unless date_of_birth
          now = Time.now.utc.to_date
          now.year - date_of_birth.year - ((now.month > date_of_birth.month ||
            (now.month == date_of_birth.month && now.day >= date_of_birth.day)) ? 0 : 1)
        end

        def adult?
          age.to_i >= 18
        end

        private

        def validate!
          raise "First name is required" if first_name.nil? || first_name.empty?
          raise "Last name is required" if last_name.nil? || last_name.empty?
          raise "Date of birth is required" if date_of_birth.nil?
          raise "Client must be at least 18 years old" unless adult?
          raise "Invalid status" unless valid_status?
        end

        def valid_status?
          [:pending, :active, :suspended, :rejected].include?(status)
        end
      end
    end
  end
end
