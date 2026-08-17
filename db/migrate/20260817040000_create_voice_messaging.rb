class CreateVoiceMessaging < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :last_active_at, :datetime
    add_index :users, :last_active_at

    add_reference :rooms, :last_sender, foreign_key: { to_table: :users }
    add_column :rooms, :last_message_at, :datetime
    add_index :rooms, [ :user_id, :opponent_id ]
    add_index :rooms, :last_message_at

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
