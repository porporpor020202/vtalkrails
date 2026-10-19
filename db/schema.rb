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

ActiveRecord::Schema[8.1].define(version: 2026_10_19_120001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ai_usages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "help_data", default: {}, null: false
    t.date "help_on"
    t.string "identity_key", null: false
    t.bigint "merged_into_id"
    t.date "training_dates", default: [], null: false, array: true
    t.datetime "updated_at", null: false
    t.index ["identity_key"], name: "index_ai_usages_on_identity_key", unique: true
    t.index ["merged_into_id"], name: "index_ai_usages_on_merged_into_id"
  end

  create_table "bonus_practices", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "daily_practice_id", null: false
    t.integer "duration_ms"
    t.text "english_sentence"
    t.string "question", null: false
    t.datetime "shared_at", null: false
    t.string "source", null: false
    t.datetime "updated_at", null: false
    t.index ["daily_practice_id"], name: "index_bonus_practices_on_daily_practice_id", unique: true
  end

  create_table "daily_practices", force: :cascade do |t|
    t.datetime "completed_at", null: false
    t.datetime "created_at", null: false
    t.bigint "daily_question_id", null: false
    t.integer "duration_ms", null: false
    t.text "english_sentence"
    t.date "practiced_on", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["daily_question_id"], name: "index_daily_practices_on_daily_question_id"
    t.index ["user_id", "practiced_on"], name: "index_daily_practices_on_user_id_and_practiced_on", unique: true
    t.index ["user_id"], name: "index_daily_practices_on_user_id"
  end

  create_table "daily_questions", force: :cascade do |t|
    t.date "asked_on", null: false
    t.datetime "created_at", null: false
    t.string "question", null: false
    t.string "source", null: false
    t.datetime "updated_at", null: false
    t.index ["asked_on"], name: "index_daily_questions_on_asked_on", unique: true
  end

  create_table "marketing_events", force: :cascade do |t|
    t.boolean "authenticated", default: false, null: false
    t.string "context", default: "daily", null: false
    t.string "deduplication_key", null: false
    t.bigint "marketing_visit_id"
    t.string "name", null: false
    t.datetime "occurred_at", null: false
    t.bigint "user_id"
    t.index ["deduplication_key"], name: "index_marketing_events_on_deduplication_key", unique: true
    t.index ["marketing_visit_id"], name: "index_marketing_events_on_marketing_visit_id"
    t.index ["name", "occurred_at"], name: "index_marketing_events_on_name_and_occurred_at"
    t.index ["user_id", "occurred_at"], name: "index_marketing_events_on_user_id_and_occurred_at"
    t.index ["user_id"], name: "index_marketing_events_on_user_id"
  end

  create_table "marketing_visits", force: :cascade do |t|
    t.string "campaign"
    t.string "content"
    t.boolean "internal", default: false, null: false
    t.string "landing_path", null: false
    t.datetime "last_seen_at", null: false
    t.string "medium", null: false
    t.string "platform", null: false
    t.string "referrer_host"
    t.string "source", null: false
    t.datetime "started_at", null: false
    t.bigint "user_id"
    t.string "visitor_key", null: false
    t.index ["last_seen_at"], name: "index_marketing_visits_on_last_seen_at"
    t.index ["started_at", "source", "campaign"], name: "index_marketing_visits_on_started_at_and_source_and_campaign"
    t.index ["user_id"], name: "index_marketing_visits_on_user_id"
    t.index ["visitor_key", "started_at"], name: "index_marketing_visits_on_visitor_key_and_started_at"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.datetime "last_active_at"
    t.string "native_language"
    t.string "oauth_provider", null: false
    t.string "oauth_uid", null: false
    t.datetime "updated_at", null: false
    t.index ["last_active_at"], name: "index_users_on_last_active_at"
    t.index ["oauth_provider", "oauth_uid"], name: "index_users_on_oauth_provider_and_oauth_uid", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ai_usages", "ai_usages", column: "merged_into_id"
  add_foreign_key "bonus_practices", "daily_practices"
  add_foreign_key "daily_practices", "daily_questions"
  add_foreign_key "daily_practices", "users"
  add_foreign_key "marketing_events", "marketing_visits"
  add_foreign_key "marketing_events", "users"
  add_foreign_key "marketing_visits", "users"
  add_foreign_key "sessions", "users"
end
