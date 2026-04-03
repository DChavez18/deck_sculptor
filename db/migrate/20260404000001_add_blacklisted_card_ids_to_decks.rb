class AddBlacklistedCardIdsToDecks < ActiveRecord::Migration[8.0]
  def change
    add_column :decks, :blacklisted_card_ids, :string, array: true, default: []

    reversible do |dir|
      dir.up do
        SuggestionFeedback.where(feedback: "down").find_each do |fb|
          fb.deck.blacklist_card(fb.scryfall_id)
        end
      end
    end
  end
end
