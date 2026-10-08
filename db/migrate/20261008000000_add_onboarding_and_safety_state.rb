class AddOnboardingAndSafetyState < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_tokens do |t|
      t.bigint :user_id, null: false
      t.string :token, null: false
      t.string :platform, null: false
      t.timestamps
    end
    add_index :notification_tokens, :user_id
    add_foreign_key :notification_tokens, :users

    add_column :users, :age_confirmed_at, :datetime
    add_column :users, :onboarding_completed_at, :datetime
    add_column :users, :suspended_at, :datetime
    add_column :users, :receive_new_rooms, :boolean, default: true, null: false

    change_column_null :rooms, :host_id, true
    change_column_null :rooms, :opponent_id, true
    add_column :rooms, :status, :string, default: "active", null: false
    add_column :rooms, :deleted_by_id, :bigint
    add_column :rooms, :dismissed_by_id, :bigint

    add_column :voice_messages, :moderation_status, :string, default: "approved", null: false

    add_column :content_reports, :resolution, :text
    add_column :content_reports, :reviewed_at, :datetime
    add_column :content_reports, :reviewed_by_id, :bigint
    add_foreign_key :content_reports, :users, column: :reviewed_by_id, on_delete: :nullify
  end
end
