class CreateCards < ActiveRecord::Migration[8.0]
  def change
    create_table :cards do |t|
      t.string  :scryfall_id,    null: false
      t.string  :name,           null: false
      t.string  :type_line
      t.text    :oracle_text
      t.string  :image_uri
      t.decimal :cmc,            precision: 4, scale: 1
      t.string  :color_identity

      t.timestamps
    end

    add_index :cards, :scryfall_id, unique: true
  end
end
