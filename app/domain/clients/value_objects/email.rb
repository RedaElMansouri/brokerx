module Domain
  module Clients
    module ValueObjects
      class Email < Domain::Shared::ValueObject
        attr_reader :value

        def initialize(value)
          raise ArgumentError, "Invalid email format" unless valid?(value)
          @value = value.downcase.strip
        end

        def to_s
          value
        end

        private

        def valid?(email)
          return false if email.nil? || email.empty?

          # Simple regex validation -> It's a fairly robust email validation pattern commonly used in Rails applications.
          pattern = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
          pattern.match?(email)
        end
      end
    end
  end
end
