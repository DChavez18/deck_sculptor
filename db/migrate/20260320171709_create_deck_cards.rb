class CreateDeckCards < ActiveRecord::Migration[8.0]
  def change
    create_table :deck_cards do |t|
      t.references :deck,           null: false, foreign_key: true
      t.string     :scryfall_id,    null: false
      t.string     :card_name,      null: false
      t.integer    :quantity,       default: 1
      t.string     :category
      t.string     :mana_cost
      t.decimal    :cmc,            precision: 4, scale: 1
      t.string     :type_line
      t.string     :color_identity, array: true, default: []
      t.text       :oracle_text
      t.string     :image_uri
      t.jsonb      :raw_data,       default: {}
      t.timestamps
    end
    add_index :deck_cards, [:deck_id, :scryfall_id], unique: true
    add_index :deck_cards, :category
  end
end
