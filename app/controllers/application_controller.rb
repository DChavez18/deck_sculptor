class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  private

  def blacklisted_ids_for(deck)
    ids = deck.suggestion_feedbacks.pluck(:scryfall_id).to_set
    ids << deck.commander.scryfall_id
    deck.deck_cards.pluck(:scryfall_id).compact.each { |id| ids << id }
    ids
  end

  def blacklisted_names_for(deck)
    names = deck.suggestion_feedbacks.pluck(:card_name)
                .map { |n| n.to_s.downcase }.to_set
    names << deck.commander.name.to_s.downcase
    deck.deck_cards.pluck(:card_name).map { |n| n.to_s.downcase }
                   .each { |n| names << n }
    names
  end

  def blacklisted?(suggestion, deck)
    card  = suggestion[:card]
    ids   = blacklisted_ids_for(deck)
    names = blacklisted_names_for(deck)
    ids.include?(card["id"]) ||
      ids.include?(card["scryfall_id"]) ||
      names.include?(card["name"].to_s.downcase)
  end
end
