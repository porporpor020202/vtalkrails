class CreateCommunity < ActiveRecord::Migration[8.1]
  def change
    create_table :posts do |t|
      t.references :language, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false
      t.integer :comments_count, null: false, default: 0
      t.timestamps
      t.index [:language_id, :created_at, :id]
    end

    create_table :comments do |t|
      t.references :post, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false
      t.timestamps
      t.index [:post_id, :created_at, :id]
    end
  end
end
