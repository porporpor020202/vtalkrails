class CreateFeedbackReplies < ActiveRecord::Migration[8.1]
  def change
    create_table :feedback_replies do |t|
      t.references :feedback, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true, index: false
      t.text :body, null: false
      t.timestamps
    end

    add_index :feedback_replies, :feedback_id
    add_index :feedback_replies, :user_id
  end
end
