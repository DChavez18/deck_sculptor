class CreateCommanders < ActiveRecord::Migration[8.0]
  def change
    create_table :commanders do |t|
      t.string  :scryfall_id,   null: false
      t.string  :name,          null: false
      t.string  :color_identity
      t.string  :type_line
      t.text    :oracle_text
      t.string  :mana_cost
      t.string  :image_uri
      t.integer :edhrec_rank
      t.jsonb   :legalities,    default: {}
      t.string  :keywords,      array: true, default: []
      t.jsonb   :raw_data,      default: {}
      t.timestamps
    end
    add_index :commanders, :scryfall_id, unique: true
    add_index :commanders, :name
  end
end
