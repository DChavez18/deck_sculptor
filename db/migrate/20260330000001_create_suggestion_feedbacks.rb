class CreateSuggestionFeedbacks < ActiveRecord::Migration[8.0]
  def change
    create_table :suggestion_feedbacks do |t|
      t.references :deck, null: false, foreign_key: true
      t.string :scryfall_id, null: false
      t.string :card_name,   null: false
      t.string :feedback,    null: false

      t.timestamps
    end

    add_index :suggestion_feedbacks, [ :deck_id, :scryfall_id ], unique: true
  end
end
