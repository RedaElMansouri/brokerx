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

ActiveRecord::Schema[7.1].define(version: 2025_11_18_090000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "audit_events", force: :cascade do |t|
    t.datetime "occurred_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.bigint "actor_id"
    t.bigint "account_id"
    t.string "event_type", null: false
    t.string "entity_type", null: false
    t.bigint "entity_id"
    t.jsonb "payload", default: {}, null: false
    t.string "correlation_id"
    t.index ["account_id", "occurred_at"], name: "index_audit_events_on_account_id_and_occurred_at"
    t.index ["event_type", "occurred_at"], name: "index_audit_events_on_event_type_and_occurred_at"
    t.index ["occurred_at"], name: "index_audit_events_on_occurred_at"
  end

  create_table "clients", force: :cascade do |t|
    t.string "email", null: false
    t.string "phone"
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.date "date_of_birth", null: false
    t.string "status", default: "pending", null: false
    t.string "verification_token"
    t.datetime "verified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "mfa_code"
    t.datetime "mfa_sent_at"
    t.string "password_digest"
    t.integer "mfa_attempts", default: 0, null: false
    t.datetime "last_mfa_attempt_at"
    t.index ["email"], name: "index_clients_on_email", unique: true
    t.index ["mfa_code"], name: "index_clients_on_mfa_code"
    t.index ["password_digest"], name: "index_clients_on_password_digest"
    t.index ["status"], name: "index_clients_on_status"
    t.index ["verification_token"], name: "index_clients_on_verification_token"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "symbol", null: false
    t.string "order_type", null: false
    t.string "direction", null: false
    t.integer "quantity", null: false
    t.decimal "price", precision: 15, scale: 4
    t.string "time_in_force", default: "DAY", null: false
    t.string "status", default: "new", null: false
    t.decimal "reserved_amount", precision: 15, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.string "client_order_id"
    t.index ["account_id", "client_order_id"], name: "index_orders_on_account_and_client_order_id_unique", unique: true, where: "(client_order_id IS NOT NULL)"
    t.index ["account_id"], name: "index_orders_on_account_id"
    t.index ["status"], name: "index_orders_on_status"
    t.index ["symbol"], name: "index_orders_on_symbol"
  end

  create_table "outbox_events", force: :cascade do |t|
    t.string "event_type", null: false
    t.string "status", default: "pending", null: false
    t.integer "attempts", default: 0, null: false
    t.string "correlation_id"
    t.string "entity_type"
    t.bigint "entity_id"
    t.jsonb "payload", default: {}, null: false
    t.text "last_error"
    t.datetime "produced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_outbox_events_on_created_at"
    t.index ["entity_type", "entity_id"], name: "index_outbox_events_on_entity_type_and_entity_id"
    t.index ["event_type"], name: "index_outbox_events_on_event_type"
    t.index ["status"], name: "index_outbox_events_on_status"
  end

  create_table "portfolio_transactions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "operation_type", default: "deposit", null: false
    t.decimal "amount", precision: 15, scale: 2, null: false
    t.string "currency", null: false
    t.string "status", default: "pending", null: false
    t.string "idempotency_key"
    t.string "external_reference"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "settled_at"
    t.text "failure_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "idempotency_key"], name: "index_portfolio_transactions_on_account_id_and_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["account_id"], name: "index_portfolio_transactions_on_account_id"
    t.index ["status"], name: "index_portfolio_transactions_on_status"
  end

  create_table "portfolios", force: :cascade do |t|
    t.string "currency", null: false
    t.decimal "available_balance", precision: 15, scale: 2, default: "0.0"
    t.decimal "reserved_balance", precision: 15, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "account_id", null: false
    t.index ["account_id"], name: "index_portfolios_on_account_id", unique: true
    t.index ["currency"], name: "index_portfolios_on_currency"
  end

  create_table "trades", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "account_id", null: false
    t.string "symbol", null: false
    t.integer "quantity", null: false
    t.decimal "price", precision: 15, scale: 4, default: "0.0", null: false
    t.string "side", null: false
    t.string "status", default: "executed", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_trades_on_account_id"
    t.index ["order_id"], name: "index_trades_on_order_id"
    t.index ["symbol"], name: "index_trades_on_symbol"
  end

  add_foreign_key "orders", "clients", column: "account_id"
  add_foreign_key "portfolio_transactions", "clients", column: "account_id"
  add_foreign_key "portfolios", "clients", column: "account_id"
  add_foreign_key "trades", "clients", column: "account_id"
  add_foreign_key "trades", "orders"
end
