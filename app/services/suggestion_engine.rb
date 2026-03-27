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
    service        = ScryfallService.new
    colors         = commander_card["color_identity"] || []

    raw_cards     = service.commander_suggestions(commander_card)
    broader_cards = service.cards_by_color_identity(colors)
    edhrec_cards  = fetch_edhrec_cards(service)

    all_cards  = (raw_cards + broader_cards + edhrec_cards).uniq { |c| c["name"] }
    deck_ids   = @deck.deck_cards.pluck(:scryfall_id).to_set
    deck_names = @deck.deck_cards.pluck(:card_name).map { |n| n.to_s.downcase }.to_set

    all_cards
      .reject { |c| deck_ids.include?(c["id"]) || deck_names.include?(c["name"].to_s.downcase) }
      .map    { |c| score_card(c, commander_card) }
      .sort_by { |s| -s[:score] }
  end

  private

  def fetch_edhrec_cards(service)
    top = EdhrecService.new.top_cards_with_details(@deck.commander.name)
    @edhrec_card_names    = Set.new(top.map { |c| c[:name] })
    @edhrec_synergy_scores = top.each_with_object({}) { |c, h| h[c[:name]] = c[:synergy] }
    top.filter_map { |c| service.find_card_by_name(c[:name]) }
  end

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

    qualified_map = commander_qualified_keywords(commander_card)
    shared = (commander_card["keywords"] || []) & (card["keywords"] || [])
    matching = shared.select do |kw|
      qualifier = qualified_map[kw.downcase]
      qualifier ? card["oracle_text"].to_s.match?(/\b#{Regexp.escape(kw)}\s+#{Regexp.escape(qualifier)}/i) : true
    end
    if matching.any?
      score   += 3
      reasons << "Shares keyword: #{matching.first}"
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

    edhrec_score, edhrec_reason = edhrec_boost(card)
    if edhrec_score > 0
      score   += edhrec_score
      reasons << edhrec_reason
    end

    theme_result = theme_boost(card)
    if theme_result[:score] > 0
      score   += theme_result[:score]
      reasons.concat(theme_result[:reasons])
    end

    { card: card, score: score, reasons: reasons }
  end

  def edhrec_boost(card)
    synergy = @edhrec_synergy_scores&.fetch(card["name"], nil)
    return [ 0, nil ] unless synergy

    if synergy >= 0.3
      [ 3, "High synergy staple" ]
    elsif synergy >= 0.1
      [ 2, "Commander staple" ]
    elsif synergy > 0
      [ 1, "Popular pick" ]
    else
      [ 0, nil ]
    end
  end

  def commander_qualified_keywords(commander_card)
    oracle    = commander_card["oracle_text"].to_s
    keywords  = commander_card["keywords"] || []
    keywords.each_with_object({}) do |kw, result|
      match = oracle.match(/\b#{Regexp.escape(kw)}\s+([A-Z][a-zA-Z]+)/i)
      result[kw.downcase] = match[1] if match
    end
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

  def theme_boost(card)
    return { score: 0, reasons: [] } if @deck.themes.blank?

    keywords = @deck.themes.split(",").map(&:strip).reject(&:blank?)
    return { score: 0, reasons: [] } if keywords.empty?

    card_text = "#{card['oracle_text']} #{card['type_line']}".downcase
    matched   = keywords.select { |kw| card_text.include?(kw.downcase) }.first(2)
    return { score: 0, reasons: [] } if matched.empty?

    { score: matched.size * 2, reasons: matched.map { |kw| "Matches your theme: #{kw}" } }
  end

  def archetype_boost(card)
    boost = ARCHETYPE_BOOSTS[detected_archetype]
    return 0 unless boost

    card_oracle   = card["oracle_text"].to_s.downcase
    card_category = CardCategorizer.new(card).category.to_s

    category_match = boost[:categories].any? { |cat| card_category == cat }
    keyword_match  = boost[:keywords].any?   { |kw|  card_oracle.include?(kw) }

    (category_match || keyword_match) ? 2 : 0
  end
end
