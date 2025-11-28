# frozen_string_literal: true

class CreateOutboxEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :outbox_events, id: :uuid do |t|
      t.string :aggregate_type, null: false
      t.uuid :aggregate_id, null: false
      t.string :event_type, null: false
      t.jsonb :payload, null: false, default: {}
      t.string :status, default: 'pending', null: false
      t.integer :retry_count, default: 0, null: false
      t.text :last_error
      t.datetime :processed_at

      t.timestamps
    end

    add_index :outbox_events, :status
    add_index :outbox_events, [:status, :created_at]
    add_index :outbox_events, :event_type
    add_index :outbox_events, [:aggregate_type, :aggregate_id]
  end
end
