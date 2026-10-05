class CreateContentReports < ActiveRecord::Migration[8.1]
  def change
    create_table :content_reports do |t|
      t.references :room, null: false, foreign_key: true
      t.references :reporter, null: false, foreign_key: { to_table: :users }
      t.references :reported_user, null: false, foreign_key: { to_table: :users }
      t.string :reason, null: false
      t.text :details
      t.string :status, null: false, default: "pending"

      t.timestamps
    end

    add_index :content_reports, :status
  end
end
