class BackfillUniqueUserNames < ActiveRecord::Migration[8.1]
  def up
    require Rails.root.join("app/services/user_display_name_generator").to_s

    say_with_time "Assigning unique display names to users" do
      User.reset_column_information
      User.order(:id).find_each do |user|
        identity = UserDisplayNameGenerator.for_id(user.id)
        user.update_columns(name: identity.name, icon: identity.icon)
      end
    end

    unless index_exists?(:users, :name, name: :index_users_on_name_unique)
      add_index :users, :name,
        unique: true,
        where: "name IS NOT NULL",
        name: :index_users_on_name_unique
    end
  end

  def down
    remove_index :users, name: :index_users_on_name_unique
  end
end
