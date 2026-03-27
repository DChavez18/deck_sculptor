require "set"

class SuggestionEngine
  CREATURE_THRESHOLD = 10

  ARCHETYPE_BOOSTS = {
    "combo"   => { categories: %w[instant sorcery combo], keywords: %w[tutor storm copy] },
    "aggro"   => { categories: %w[creature],              keywords: %w[haste token] },
    "control" => { categories: %w[instant removal],       keywords: %w[counter exile destroy] }
  }.freeze

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

  def detected_archetype
    @detected_archetype ||= ArchetypeDetector.new(@deck).detect
  end

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

    archetype_boost = archetype_boost(card)
    if archetype_boost > 0
      score   += archetype_boost
      reasons << "Fits #{detected_archetype} strategy"
    end

    if combo_synergy_boost?(card)
      score   += 3
      reasons << "Combo piece"
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

  def combo_synergy_boost?(card)
    return false if deck_combos.empty?

    deck_names = Set.new(@deck.deck_cards.pluck(:card_name)) << @deck.commander.name
    card_name  = card["name"]

    deck_combos.any? do |combo|
      next false unless combo[:cards].include?(card_name)

      other_combo_cards = combo[:cards].reject { |c| c == card_name }
      (Set.new(other_combo_cards) & deck_names).size >= 2
    end
  end

  def deck_combos
    @deck_combos ||= ComboFinderService.new.find_combos([ @deck.commander.name ])
  end

  def archetype_boost(card)
    boost = ARCHETYPE_BOOSTS[detected_archetype]
    return 0 unless boost

    card_type     = card["type_line"].to_s.downcase
    card_oracle   = card["oracle_text"].to_s.downcase
    card_category = CardCategorizer.new(card).category.to_s

    category_match = boost[:categories].any? { |cat| card_category == cat }
    keyword_match  = boost[:keywords].any?   { |kw|  card_oracle.include?(kw) }

    (category_match || keyword_match) ? 2 : 0
  end
end
