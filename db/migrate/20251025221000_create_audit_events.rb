class CreateAuditEvents < ActiveRecord::Migration[7.1]
  def up
    create_table :audit_events do |t|
      t.datetime :occurred_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.bigint :actor_id
      t.bigint :account_id
      t.string :event_type, null: false
      t.string :entity_type, null: false
      t.bigint :entity_id
      t.jsonb :payload, null: false, default: {}
      t.string :correlation_id
    end

    add_index :audit_events, :occurred_at
    add_index :audit_events, [:account_id, :occurred_at]
    add_index :audit_events, [:event_type, :occurred_at]

    execute <<~SQL
      CREATE OR REPLACE FUNCTION prevent_audit_events_modify()
      RETURNS trigger AS $$
      BEGIN
        RAISE EXCEPTION 'audit_events are append-only';
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER audit_events_prevent_update
      BEFORE UPDATE ON audit_events
      FOR EACH ROW EXECUTE FUNCTION prevent_audit_events_modify();

      CREATE TRIGGER audit_events_prevent_delete
      BEFORE DELETE ON audit_events
      FOR EACH ROW EXECUTE FUNCTION prevent_audit_events_modify();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS audit_events_prevent_update ON audit_events;
      DROP TRIGGER IF EXISTS audit_events_prevent_delete ON audit_events;
      DROP FUNCTION IF EXISTS prevent_audit_events_modify();
    SQL
    drop_table :audit_events
  end
end
