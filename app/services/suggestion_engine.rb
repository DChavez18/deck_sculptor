require "set"

class SuggestionEngine
  CREATURE_THRESHOLD = 10

  def initialize(deck)
    @deck = deck
  end

  def suggestions
    commander_card = @deck.commander.raw_data.presence || {}
    service = ScryfallService.new
    colors  = commander_card["color_identity"] || []

    raw_cards    = service.commander_suggestions(commander_card)
    broader_cards = service.cards_by_color_identity(colors)

    all_cards  = (raw_cards + broader_cards).uniq { |c| c["id"] }
    deck_ids   = @deck.deck_cards.pluck(:scryfall_id).to_set

    all_cards
      .reject { |c| deck_ids.include?(c["id"]) }
      .map    { |c| score_card(c, commander_card) }
      .sort_by { |s| -s[:score] }
  end

  private

  def score_card(card, commander_card)
    score   = 0
    reasons = []

    if within_color_identity?(card, commander_card)
      score   += 1
      reasons << "Within color identity"
    end

    shared = (commander_card["keywords"] || []) & (card["keywords"] || [])
    if shared.any?
      score   += 3
      reasons << "Shares keyword: #{shared.first}"
    end

    gap = mana_curve_gap
    if gap && card["cmc"].to_i == gap
      score   += 2
      reasons << "Fills mana curve gap at #{gap}"
    end

    if fills_category_gap?(card)
      score   += 2
      reasons << "Fills underrepresented category"
    end

    { card: card, score: score, reasons: reasons }
  end

  def within_color_identity?(card, commander_card)
    commander_colors = Set.new(commander_card["color_identity"] || [])
    card_colors      = Set.new(card["color_identity"] || [])
    card_colors.subset?(commander_colors)
  end

  def mana_curve_gap
    curve = @deck.mana_curve
    return nil if curve.empty?

    (1..6).min_by { |cmc| curve.fetch(cmc, 0) }
  end

  def fills_category_gap?(card)
    creature_count = @deck.deck_cards.where(category: "creature").sum(:quantity)
    return false unless creature_count < CREATURE_THRESHOLD

    card["type_line"].to_s.include?("Creature")
  end
end
