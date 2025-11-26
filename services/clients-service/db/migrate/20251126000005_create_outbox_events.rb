# frozen_string_literal: true

class CreateOutboxEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :outbox_events, id: :uuid do |t|
      t.string :aggregate_type, null: false
      t.uuid :aggregate_id, null: false
      t.string :event_type, null: false
      t.jsonb :payload, null: false, default: {}
      t.boolean :processed, default: false, null: false
      t.datetime :processed_at

      t.timestamps
    end

    add_index :outbox_events, :processed
    add_index :outbox_events, [:aggregate_type, :aggregate_id]
    add_index :outbox_events, :event_type
  end
end
