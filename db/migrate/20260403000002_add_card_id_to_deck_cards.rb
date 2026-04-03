class AddCardIdToDeckCards < ActiveRecord::Migration[8.0]
  def change
    add_reference :deck_cards, :card, foreign_key: true, null: true

    reversible do |dir|
      dir.up do
        DeckCard.find_each do |dc|
          next unless dc.scryfall_id.present?

          card_hash = CardCache.fetch(dc.scryfall_id)
          next unless card_hash

          card = Card.find_or_create_from_scryfall(card_hash)
          dc.update_column(:card_id, card.id)
        end
      end
    end
  end
end
