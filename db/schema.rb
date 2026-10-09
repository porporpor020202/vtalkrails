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

ActiveRecord::Schema[8.1].define(version: 2026_10_09_050000) do
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

  create_table "content_reports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "details"
    t.string "reason", null: false
    t.bigint "reported_user_id", null: false
    t.bigint "reporter_id", null: false
    t.text "resolution"
    t.datetime "reviewed_at"
    t.bigint "reviewed_by_id"
    t.bigint "room_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["reported_user_id"], name: "index_content_reports_on_reported_user_id"
    t.index ["reporter_id"], name: "index_content_reports_on_reporter_id"
    t.index ["room_id"], name: "index_content_reports_on_room_id"
    t.index ["status"], name: "index_content_reports_on_status"
  end

  create_table "feedback_replies", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.bigint "feedback_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["feedback_id"], name: "index_feedback_replies_on_feedback_id"
    t.index ["user_id"], name: "index_feedback_replies_on_user_id"
  end

  create_table "feedbacks", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_feedbacks_on_user_id"
  end

  create_table "languages", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.boolean "enable", default: false, null: false
    t.string "label", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_languages_on_code", unique: true
    t.index ["label"], name: "index_languages_on_label", unique: true
  end

  create_table "notification_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "platform", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_notification_tokens_on_user_id"
  end

  create_table "rooms", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "deleted_by_id"
    t.bigint "dismissed_by_id"
    t.bigint "host_id"
    t.bigint "language_id"
    t.bigint "opponent_id"
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["host_id", "opponent_id"], name: "index_rooms_on_host_id_and_opponent_id"
    t.index ["host_id"], name: "index_rooms_on_host_id"
    t.index ["language_id"], name: "index_rooms_on_language_id"
    t.index ["opponent_id"], name: "index_rooms_on_opponent_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "user_blocks", force: :cascade do |t|
    t.bigint "blocked_id", null: false
    t.bigint "blocker_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["blocked_id"], name: "index_user_blocks_on_blocked_id"
    t.index ["blocker_id", "blocked_id"], name: "index_user_blocks_on_blocker_id_and_blocked_id", unique: true
    t.index ["blocker_id"], name: "index_user_blocks_on_blocker_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "age_confirmed_at"
    t.datetime "created_at", null: false
    t.string "display_name"
    t.string "email_address", null: false
    t.datetime "last_active_at"
    t.bigint "learning_language_id"
    t.bigint "native_language_id"
    t.string "oauth_provider", null: false
    t.string "oauth_uid", null: false
    t.datetime "onboarding_completed_at"
    t.boolean "receive_new_rooms", default: true, null: false
    t.datetime "suspended_at"
    t.datetime "updated_at", null: false
    t.index ["display_name"], name: "index_users_on_display_name", unique: true
    t.index ["learning_language_id"], name: "index_users_on_learning_language_id"
    t.index ["native_language_id"], name: "index_users_on_native_language_id"
    t.index ["oauth_provider", "oauth_uid"], name: "index_users_on_oauth_provider_and_oauth_uid", unique: true
  end

  create_table "voice_drops", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "language_id"
    t.integer "recipient_count", null: false
    t.string "request_key", null: false
    t.bigint "sender_id", null: false
    t.datetime "updated_at", null: false
    t.index ["language_id"], name: "index_voice_drops_on_language_id"
    t.index ["sender_id", "request_key"], name: "index_voice_drops_on_sender_id_and_request_key", unique: true
  end

  create_table "voice_messages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "duration_ms", null: false
    t.string "moderation_status", default: "approved", null: false
    t.bigint "room_id", null: false
    t.bigint "sender_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "voice_drop_id"
    t.index ["room_id"], name: "index_voice_messages_on_room_id"
    t.index ["sender_id"], name: "index_voice_messages_on_sender_id"
    t.index ["voice_drop_id"], name: "index_voice_messages_on_voice_drop_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "content_reports", "rooms"
  add_foreign_key "content_reports", "users", column: "reported_user_id"
  add_foreign_key "content_reports", "users", column: "reporter_id"
  add_foreign_key "content_reports", "users", column: "reviewed_by_id", on_delete: :nullify
  add_foreign_key "feedback_replies", "feedbacks"
  add_foreign_key "feedback_replies", "users"
  add_foreign_key "feedbacks", "users"
  add_foreign_key "notification_tokens", "users"
  add_foreign_key "rooms", "languages"
  add_foreign_key "rooms", "users", column: "host_id"
  add_foreign_key "rooms", "users", column: "opponent_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "user_blocks", "users", column: "blocked_id"
  add_foreign_key "user_blocks", "users", column: "blocker_id"
  add_foreign_key "users", "languages", column: "learning_language_id"
  add_foreign_key "users", "languages", column: "native_language_id"
  add_foreign_key "voice_drops", "languages"
  add_foreign_key "voice_drops", "users", column: "sender_id"
  add_foreign_key "voice_messages", "rooms"
  add_foreign_key "voice_messages", "users", column: "sender_id"
  add_foreign_key "voice_messages", "voice_drops"
end
