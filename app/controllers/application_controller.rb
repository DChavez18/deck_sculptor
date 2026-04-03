class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  private

  def blacklisted?(suggestion, deck)
    scryfall_id = suggestion[:card]["id"] || suggestion[:card]["scryfall_id"]
    deck.card_blacklisted?(scryfall_id) ||
      deck.deck_cards.pluck(:scryfall_id).compact.include?(scryfall_id) ||
      scryfall_id == deck.commander.scryfall_id
  end
end
