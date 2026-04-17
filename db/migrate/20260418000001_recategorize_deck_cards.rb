class RecategorizeDeckCards < ActiveRecord::Migration[8.0]
  def up
    service = ScryfallService.new
    DeckCard.find_each do |deck_card|
      card_data = CardCache.fetch(deck_card.scryfall_id)
      card_data ||= service.find_card_by_id(deck_card.scryfall_id)
      next unless card_data
      category = CardCategorizer.new(card_data).category
      deck_card.update_column(:category, category)
    end
  end

  def down
    # irreversible — categories are computed values
  end
end
