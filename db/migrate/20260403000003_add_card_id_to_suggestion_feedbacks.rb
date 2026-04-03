class AddCardIdToSuggestionFeedbacks < ActiveRecord::Migration[8.0]
  def change
    add_reference :suggestion_feedbacks, :card, foreign_key: true, null: true

    reversible do |dir|
      dir.up do
        SuggestionFeedback.find_each do |fb|
          card = Card.find_by(scryfall_id: fb.scryfall_id)
          fb.update_column(:card_id, card.id) if card
        end
      end
    end
  end
end
