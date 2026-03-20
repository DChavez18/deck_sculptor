class CreateDecks < ActiveRecord::Migration[8.0]
  def change
    create_table :decks do |t|
      t.string     :name,        null: false
      t.references :commander,   null: false, foreign_key: true
      t.text       :description
      t.string     :archetype
      t.integer    :power_level, default: 5
      t.timestamps
    end
  end
end
