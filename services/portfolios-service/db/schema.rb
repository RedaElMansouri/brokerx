# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2024_11_28_100001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "outbox_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "aggregate_type", null: false
    t.uuid "aggregate_id", null: false
    t.string "event_type", null: false
    t.jsonb "payload", default: {}, null: false
    t.string "status", default: "pending", null: false
    t.integer "retry_count", default: 0, null: false
    t.text "last_error"
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["aggregate_type", "aggregate_id"], name: "index_outbox_events_on_aggregate_type_and_aggregate_id"
    t.index ["aggregate_type"], name: "index_outbox_events_on_aggregate_type"
    t.index ["status", "created_at"], name: "index_outbox_events_on_status_and_created_at"
    t.index ["status"], name: "index_outbox_events_on_status"
  end

  create_table "portfolio_transactions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "portfolio_id", null: false
    t.string "transaction_type", null: false
    t.decimal "amount", precision: 15, scale: 2, null: false
    t.string "currency", limit: 3, default: "CAD", null: false
    t.string "status", default: "pending", null: false
    t.string "idempotency_key", null: false
    t.datetime "processed_at"
    t.string "failure_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_portfolio_transactions_on_created_at"
    t.index ["idempotency_key"], name: "index_portfolio_transactions_on_idempotency_key"
    t.index ["portfolio_id", "idempotency_key"], name: "idx_portfolio_transactions_idempotency", unique: true
    t.index ["portfolio_id"], name: "index_portfolio_transactions_on_portfolio_id"
    t.index ["status"], name: "index_portfolio_transactions_on_status"
    t.index ["transaction_type"], name: "index_portfolio_transactions_on_transaction_type"
  end

  create_table "portfolios", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "client_id", null: false
    t.string "name", null: false
    t.decimal "cash_balance", precision: 15, scale: 2, default: "0.0", null: false
    t.string "currency", limit: 3, default: "CAD", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "reserved_amount", precision: 15, scale: 2, default: "0.0", null: false
    t.index ["client_id", "status"], name: "index_portfolios_on_client_id_and_status"
    t.index ["client_id"], name: "index_portfolios_on_client_id"
    t.index ["status"], name: "index_portfolios_on_status"
  end

  add_foreign_key "portfolio_transactions", "portfolios"
end
