class CreateLanguages < ActiveRecord::Migration[8.1]
  def change
    create_table :languages do |t|
      t.string :code, null: false
      t.string :name, null: false

      t.timestamps

      t.index :code, unique: true
    end
  end
end
