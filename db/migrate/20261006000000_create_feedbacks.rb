class CreateFeedbacks < ActiveRecord::Migration[8.1]
  def change
    create_table :feedbacks do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :title, null: false
      t.text :body, null: false
      t.timestamps
    end

    add_index :feedbacks, :user_id
  end
end
