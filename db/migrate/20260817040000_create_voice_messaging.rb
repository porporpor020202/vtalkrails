class CreateVoiceMessaging < ActiveRecord::Migration[8.1]
  def change
    create_table :voice_drops do |t|
      t.references :sender, null: false, foreign_key: { to_table: :users }
      t.references :language, null: false, foreign_key: true
      t.string :request_key, null: false
      t.integer :recipient_count, null: false, default: 0
      t.timestamps
      t.index [:sender_id, :request_key], unique: true
    end

    create_table :voice_deliveries do |t|
      t.references :voice_drop, null: false, foreign_key: true
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      t.references :room, foreign_key: true, index: { unique: true }
      t.datetime :first_replied_at
      t.timestamps
      t.index [:voice_drop_id, :recipient_id], unique: true
      t.index [:recipient_id, :created_at]
    end

    create_table :voice_messages do |t|
      t.references :room, null: false, foreign_key: true
      t.references :sender, null: false, foreign_key: { to_table: :users }
      t.integer :duration_ms, null: false

      t.timestamps
    end

    create_table :active_storage_blobs do |t|
      t.string :key, null: false
      t.string :filename, null: false
      t.string :content_type
      t.text :metadata
      t.string :service_name, null: false
      t.bigint :byte_size, null: false
      t.string :checksum

      t.datetime :created_at, null: false

      t.index :key, unique: true
    end

    create_table :active_storage_attachments do |t|
      t.string :name, null: false
      t.references :record, null: false, polymorphic: true, index: false
      t.references :blob, null: false

      t.datetime :created_at, null: false

      t.index [ :record_type, :record_id, :name, :blob_id ],
        name: :index_active_storage_attachments_uniqueness,
        unique: true
      t.foreign_key :active_storage_blobs, column: :blob_id
    end

    create_table :active_storage_variant_records do |t|
      t.belongs_to :blob, null: false, index: false
      t.string :variation_digest, null: false

      t.index [ :blob_id, :variation_digest ],
        name: :index_active_storage_variant_records_uniqueness,
        unique: true
      t.foreign_key :active_storage_blobs, column: :blob_id
    end
  end
end
