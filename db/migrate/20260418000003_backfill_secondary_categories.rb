class BackfillSecondaryCategories < ActiveRecord::Migration[8.0]
  def up
    service = ScryfallService.new
    DeckCard.find_each do |deck_card|
      card_data = CardCache.fetch(deck_card.scryfall_id)
      card_data ||= service.find_card_by_id(deck_card.scryfall_id)
      next unless card_data

      all_cats  = CardCategorizer.new(card_data).categories
      primary   = all_cats.first
      secondary = (all_cats - [ primary ]).join(",")

      deck_card.update_columns(category: primary, secondary_categories: secondary)
    end
  end

  def down
    DeckCard.update_all(secondary_categories: "")
  end
end
