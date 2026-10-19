class AllowGuestDailyPractices < ActiveRecord::Migration[8.1]
  def change
    change_column_null :daily_practices, :user_id, true
  end
end
