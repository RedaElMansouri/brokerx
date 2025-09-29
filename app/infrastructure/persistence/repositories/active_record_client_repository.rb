module Infrastructure
  module Persistence
    module Repositories
      class ActiveRecordClientRepository < Domain::Clients::Repositories::ClientRepository
        def find(id)
          record = Infrastructure::Persistence::ActiveRecord::ClientRecord.find_by(id: id)
          raise Domain::Shared::Repository::RecordNotFound, "Client not found: #{id}" unless record
          map_to_entity(record)
        end

        def find_by_email(email)
          email_value = email.is_a?(Domain::Clients::ValueObjects::Email) ? email.value : email
          record = Infrastructure::Persistence::ActiveRecord::ClientRecord.find_by(email: email_value)
          return nil unless record
          map_to_entity(record)
        end

        def find_by_verification_token(token)
          record = Infrastructure::Persistence::ActiveRecord::ClientRecord.find_by(verification_token: token)
          return nil unless record
          map_to_entity(record)
        end

        def save(client_entity)
          ::ActiveRecord::Base.transaction do
            record = Infrastructure::Persistence::ActiveRecord::ClientRecord.find_or_initialize_by(id: client_entity.id)
            record.assign_attributes(map_to_record(client_entity))

            if record.save
              client_entity.id = record.id if client_entity.id.nil?
              client_entity
            else
              raise Domain::Shared::Repository::Error, "Failed to save client: #{record.errors.full_messages}"
            end
          end
        end

        def delete(id)
          record = Infrastructure::Persistence::ActiveRecord::ClientRecord.find_by(id: id)
          return false unless record
          record.destroy
          true
        end

        def exists?(criteria)
          Infrastructure::Persistence::ActiveRecord::ClientRecord.exists?(criteria)
        end

        private

        def map_to_entity(record)
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

        def map_to_record(entity)
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
