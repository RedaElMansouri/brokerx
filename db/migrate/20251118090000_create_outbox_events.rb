class CreateOutboxEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :outbox_events do |t|
      t.string :event_type, null: false
      t.string :status, null: false, default: 'pending'
      t.integer :attempts, null: false, default: 0
      t.string :correlation_id
      t.string :entity_type
      t.bigint :entity_id
      t.jsonb :payload, null: false, default: {}
      t.text :last_error
      t.datetime :produced_at

      t.timestamps
    end

    add_index :outbox_events, :status
    add_index :outbox_events, :event_type
    add_index :outbox_events, [:entity_type, :entity_id]
    add_index :outbox_events, :created_at
  end
end
