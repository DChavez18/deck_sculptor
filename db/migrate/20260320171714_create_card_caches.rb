class CreateCardCaches < ActiveRecord::Migration[8.0]
  def change
    create_table :card_caches do |t|
      t.string   :scryfall_id, null: false
      t.string   :name,        null: false
      t.jsonb    :data,        default: {}
      t.datetime :cached_at,   null: false
      t.timestamps
    end
    add_index :card_caches, :scryfall_id, unique: true
    add_index :card_caches, :name
    add_index :card_caches, :cached_at
  end
end
