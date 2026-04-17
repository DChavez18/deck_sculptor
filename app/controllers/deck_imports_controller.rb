class DeckImportsController < ApplicationController
  before_action :set_deck

  def create
    cards = DecklistParser.new(params[:decklist].to_s).parse

    if cards.empty?
      render turbo_stream: turbo_stream.replace("import-result",
        partial: "deck_imports/error",
        locals: { message: "Could not parse decklist. Please check the format." })
      return
    end

    service   = ScryfallService.new
    imported  = 0
    skipped   = 0
    not_found = []

    cards.each do |entry|
      next if entry[:name].casecmp?(@deck.commander.name)

      card_data = CardCache.fetch_by_name(entry[:name]) ||
                  service.find_card_by_name(entry[:name])
      unless card_data
        not_found << entry[:name]
        next
      end

      all_cats  = CardCategorizer.new(card_data).categories
      primary   = all_cats.first
      secondary = (all_cats - [ primary ]).join(",")
      existing  = @deck.deck_cards.find_by(scryfall_id: card_data["id"])

      if existing
        existing.update!(quantity: entry[:quantity])
        skipped += 1
      else
        @deck.deck_cards.create!(
          scryfall_id:          card_data["id"],
          card_name:            card_data["name"],
          category:             primary,
          secondary_categories: secondary,
          quantity:             entry[:quantity],
          cmc:                  card_data["cmc"],
          color_identity:       card_data["color_identity"]&.join(","),
          type_line:            card_data["type_line"],
          image_uri:            card_data.dig("image_uris", "normal") ||
                                card_data.dig("card_faces", 0, "image_uris", "normal")
        )
        imported += 1
      end
    end

    summary = "Imported #{imported} cards"
    summary += ", skipped #{skipped} duplicates" if skipped > 0

    @deck.deck_cards.reload

    render turbo_stream: [
      turbo_stream.replace("deck_card_list",
        partial: "decks/deck_card_list",
        locals: { cards_by_category: @deck.cards_by_category, deck: @deck }),
      turbo_stream.update("deck-progress",
        partial: "decks/deck_stats",
        locals: { deck: @deck }),
      turbo_stream.replace("import-result",
        partial: "deck_imports/result",
        locals: { summary: summary, not_found: not_found })
    ]
  end

  private

  def set_deck
    @deck = Deck.find(params[:deck_id])
  end
end
