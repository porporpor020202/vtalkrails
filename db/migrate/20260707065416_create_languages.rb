class CreateLanguages < ActiveRecord::Migration[8.1]
  def change
    create_table :languages do |t|
      t.string :label, null: false
      t.string :code, null: false
      t.boolean :enable, null: false, default: false
      t.timestamps
    end

    add_index :languages, :code, unique: true
    add_index :languages, :label, unique: true
  end
end
