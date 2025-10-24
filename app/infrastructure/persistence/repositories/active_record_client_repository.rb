module Infrastructure
  module Persistence
    module Repositories
      class ActiveRecordClientRepository < Domain::Clients::Repositories::ClientRepository
        def find(id)
          record = Infrastructure::Persistence::ActiveRecord::ClientRecord.find_by(id: id)
          raise Domain::Shared::Repository::RecordNotFound, "Client not found: #{id}" unless record

          Infrastructure::Persistence::Mappers::ClientMapper.to_entity(record)
        end

        def find_by_email(email)
          email_value = email.is_a?(Domain::Clients::ValueObjects::Email) ? email.value : email
          record = Infrastructure::Persistence::ActiveRecord::ClientRecord.find_by(email: email_value)
          return nil unless record

          Infrastructure::Persistence::Mappers::ClientMapper.to_entity(record)
        end

        def find_by_verification_token(token)
          record = Infrastructure::Persistence::ActiveRecord::ClientRecord.find_by(verification_token: token)
          return nil unless record

          Infrastructure::Persistence::Mappers::ClientMapper.to_entity(record)
        end

        def save(client_entity)
          ::ActiveRecord::Base.transaction do
            record = build_or_find_record(client_entity)
            record.assign_attributes(Infrastructure::Persistence::Mappers::ClientMapper.to_record_attributes(client_entity))

            unless record.save
              raise Domain::Shared::Repository::Error, "Failed to save client: #{record.errors.full_messages}"
            end

            client_entity.id = record.id
            client_entity
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

        def build_or_find_record(entity)
          id = entity.id
          if id.is_a?(Integer) || (id.is_a?(String) && id =~ /\A\d+\z/)
            Infrastructure::Persistence::ActiveRecord::ClientRecord.find_or_initialize_by(id: id)
          else
            Infrastructure::Persistence::ActiveRecord::ClientRecord.new
          end
        end
      end
    end
  end
end
