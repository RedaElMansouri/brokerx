module Application
  module Dtos
    class ClientRegistrationDto
      attr_reader :email, :first_name, :last_name, :date_of_birth, :phone, :password

      def initialize(email:, first_name:, last_name:, date_of_birth:, phone: nil, password: nil)
        @email = email
        @first_name = first_name
        @last_name = last_name
        @date_of_birth = date_of_birth
        @phone = phone
        @password = password
      end

      def to_h
        {
          email: email,
          first_name: first_name,
          last_name: last_name,
          date_of_birth: date_of_birth,
          phone: phone,
          password: password
        }
      end
    end
  end
end
