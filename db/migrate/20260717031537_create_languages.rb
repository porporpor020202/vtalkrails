class CreateLanguages < ActiveRecord::Migration[8.1]
  def change
    create_table :languages do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.boolean :enabled, null: false, default: false
      t.timestamps

      t.index :code, unique: true
    end
  end
end
