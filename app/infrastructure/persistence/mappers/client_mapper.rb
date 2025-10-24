module Infrastructure
  module Persistence
    module Mappers
      module ClientMapper
        module_function

        def to_entity(record)
          Domain::Clients::Entities::Client.new(
            id: record.id,
            email: Domain::Clients::ValueObjects::Email.new(record.email),
            first_name: record.first_name,
            last_name: record.last_name,
            date_of_birth: record.date_of_birth,
            status: record.status.to_sym,
            verification_token: record.verification_token,
            verified_at: record.verified_at,
            created_at: record.created_at,
            updated_at: record.updated_at
          )
        end

        def to_record_attributes(entity)
          {
            email: entity.email.value,
            first_name: entity.first_name,
            last_name: entity.last_name,
            date_of_birth: entity.date_of_birth,
            status: entity.status.to_s,
            verification_token: entity.verification_token,
            verified_at: entity.verified_at
          }
        end
      end
    end
  end
end
