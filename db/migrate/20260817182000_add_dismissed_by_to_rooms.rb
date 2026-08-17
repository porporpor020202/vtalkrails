class AddDismissedByToRooms < ActiveRecord::Migration[8.1]
  def change
    add_reference :rooms, :dismissed_by, foreign_key: { to_table: :users }, index: true
  end
end
