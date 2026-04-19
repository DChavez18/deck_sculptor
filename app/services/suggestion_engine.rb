require "set"

class SuggestionEngine
  CREATURE_THRESHOLD = 10

  ARCHETYPE_BOOSTS = {
    "combo"   => { categories: %w[instant sorcery combo], keywords: %w[tutor storm copy] },
    "aggro"   => { categories: %w[creature],              keywords: %w[haste token] },
    "control" => { categories: %w[instant removal],       keywords: %w[counter exile destroy] }
  }.freeze

  def initialize(deck, liked_ids: [])
    @deck      = deck
    @liked_ids = liked_ids
  end

  def suggestions
    commander_card = @deck.commander.raw_data.presence || {}
    service        = ScryfallService.new
    colors         = commander_card["color_identity"] || []

    raw_cards       = service.commander_suggestions(commander_card)
    broader_cards   = service.cards_by_color_identity(colors)
    edhrec_cards    = fetch_edhrec_cards(service)
    cognition_cards = fetch_cognition_cards(service)

    all_cards = (raw_cards + broader_cards + edhrec_cards + cognition_cards).uniq { |c| c["name"] }

    all_cards
      .reject { |c| excluded_from_suggestions?(c) }
      .map    { |c| score_card(c, commander_card) }
      .sort_by { |s| -s[:score] }
      .reject { |s| excluded_from_suggestions?(s[:card]) }
  end

  def more_like(scryfall_ids)
    return [] if scryfall_ids.empty?

    service     = ScryfallService.new
    liked_cards = scryfall_ids.filter_map { |id| CardCache.fetch(id) || service.find_card_by_id(id) }
    return [] if liked_cards.empty?

    liked_keywords   = liked_cards.flat_map { |c| c["keywords"] || [] }.uniq
    liked_type_words = liked_cards.flat_map { |c| c["type_line"].to_s.split(/[\s\u2014\-]+/) }.map(&:downcase).uniq
    liked_cmcs       = liked_cards.map { |c| c["cmc"].to_i }
    cmc_min, cmc_max = liked_cmcs.minmax

    commander_card = @deck.commander.raw_data.presence || {}
    candidates     = service.commander_suggestions(commander_card).uniq { |c| c["name"] }

    deck_ids       = @deck.deck_cards.pluck(:scryfall_id).compact.to_set
    deck_names     = @deck.deck_cards.pluck(:card_name).map { |n| n.to_s.downcase }.to_set
    feedbacked_ids = @deck.suggestion_feedbacks.pluck(:scryfall_id).to_set
    liked_ids_set  = scryfall_ids.to_set
    commander_id   = @deck.commander.scryfall_id
    commander_name = @deck.commander.name.to_s.downcase

    candidates
      .reject { |c|
        c["id"] == commander_id ||
        c["name"].to_s.downcase == commander_name ||
        deck_ids.include?(c["id"]) ||
        deck_names.include?(c["name"].to_s.downcase)
      }
      .reject { |c| feedbacked_ids.include?(c["id"]) }
      .reject { |c| liked_ids_set.include?(c["id"]) }
      .map    { |c| score_for_more_like(c, liked_keywords, liked_type_words, cmc_min, cmc_max) }
      .sort_by { |s| -s[:score] }
      .first(3)
  end

  private

  def excluded_from_suggestions?(card)
    card["id"] == memo_commander_id ||
      card["name"].to_s.downcase == memo_commander_name ||
      memo_deck_ids.include?(card["id"]) ||
      memo_deck_names.include?(card["name"].to_s.downcase) ||
      @deck.card_blacklisted?(card["id"].to_s)
  end

  def memo_commander_id
    @memo_commander_id ||= @deck.commander.scryfall_id
  end

  def memo_commander_name
    @memo_commander_name ||= @deck.commander.name.to_s.downcase
  end

  def memo_deck_ids
    @memo_deck_ids ||= @deck.deck_cards.pluck(:scryfall_id).compact.to_set
  end

  def memo_deck_names
    @memo_deck_names ||= @deck.deck_cards.pluck(:card_name).map { |n| n.to_s.downcase }.to_set
  end

  def fetch_edhrec_cards(service)
    top = EdhrecService.new.top_cards_with_details(@deck.commander.name)
    @edhrec_card_names    = Set.new(top.map { |c| c[:name] })
    @edhrec_synergy_scores = top.each_with_object({}) { |c, h| h[c[:name]] = c[:synergy] }
    top.filter_map { |c| service.find_card_by_name(c[:name]) }
  end

  def fetch_cognition_cards(service)
    results = CardCognitionService.new(@deck.commander.name).suggestions
    @cognition_scores = results.each_with_object({}) { |r, h| h[r["name"]] = r["score"].to_f }
    results.filter_map { |r| service.find_card_by_name(r["name"]) }
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
      score   += 2
      reasons << "Shares keyword: #{matching.first}"
    end

    gap = mana_curve_gap
    if gap && card["cmc"].to_i == gap
      score   += 1
      reasons << "Fills mana curve gap at #{gap}"
    end

    if fills_category_gap?(card)
      score   += 1
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

    liked_score, liked_reason = liked_boost(card)
    if liked_score > 0
      score   += liked_score
      reasons << liked_reason
    end

    cognition_score, cognition_reason = cognition_boost(card)
    if cognition_score > 0
      score   += cognition_score
      reasons << cognition_reason
    end

    { card: card, score: score, reasons: reasons }
  end

  def edhrec_boost(card)
    synergy = @edhrec_synergy_scores&.fetch(card["name"], nil)
    return [ 0, nil ] unless synergy

    if synergy >= 0.3
      [ 8, "High synergy staple" ]
    elsif synergy >= 0.1
      [ 6, "Commander staple" ]
    elsif synergy > 0
      [ 4, "Popular pick" ]
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

  def memo_creature_count
    @memo_creature_count ||= @deck.deck_cards.where(category: "creature").sum(:quantity)
  end

  def memo_mana_curve
    @memo_mana_curve ||= @deck.mana_curve
  end

  def memo_combo_deck_names
    @memo_combo_deck_names ||= Set.new(@deck.deck_cards.pluck(:card_name)) << @deck.commander.name
  end

  def mana_curve_gap
    curve = memo_mana_curve
    return nil if curve.empty?

    (1..6).min_by { |cmc| curve.fetch(cmc, 0) }
  end

  def fills_category_gap?(card)
    return false unless memo_creature_count < CREATURE_THRESHOLD

    card["type_line"].to_s.include?("Creature")
  end

  def combo_synergy_boost?(card)
    return false if deck_combos.empty?

    deck_names = memo_combo_deck_names
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

    { score: matched.size, reasons: matched.map { |kw| "Matches your theme: #{kw}" } }
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

  def liked_signals
    return @liked_signals if defined?(@liked_signals)
    return @liked_signals = nil if @liked_ids.empty?

    service     = ScryfallService.new
    liked_cards = @liked_ids.filter_map { |id| CardCache.fetch(id) || service.find_card_by_id(id) }
    return @liked_signals = nil if liked_cards.empty?

    @liked_signals = {
      keywords:   liked_cards.flat_map { |c| c["keywords"] || [] }.uniq,
      type_words: liked_cards.flat_map { |c| c["type_line"].to_s.split(/[\s\u2014\-]+/) }.map(&:downcase).uniq,
      cmcs:       liked_cards.map { |c| c["cmc"].to_i }
    }
  end

  def liked_boost(card)
    return [ 0, nil ] unless liked_signals

    sig             = liked_signals
    matching_kws    = (card["keywords"] || []) & sig[:keywords]
    card_type_words = card["type_line"].to_s.split(/[\s\u2014\-]+/).map(&:downcase)
    type_match      = (card_type_words & sig[:type_words]).any?
    cmc             = card["cmc"].to_i
    cmc_min, cmc_max = sig[:cmcs].minmax
    cmc_match       = cmc_min && cmc >= cmc_min && cmc <= cmc_max

    if matching_kws.any? || type_match || cmc_match
      [ 2, "Synergizes with your picks" ]
    else
      [ 0, nil ]
    end
  end

  def cognition_boost(card)
    score = @cognition_scores&.fetch(card["name"], nil)
    return [ 0, nil ] unless score

    if score >= 0.5
      [ 3, "High commander synergy" ]
    elsif score >= 0.2
      [ 2, "Commander synergy" ]
    else
      [ 0, nil ]
    end
  end

  def score_for_more_like(card, liked_keywords, liked_type_words, cmc_min, cmc_max)
    score   = 0
    reasons = []

    matching_kws = (card["keywords"] || []) & liked_keywords
    if matching_kws.any?
      score   += 2
      reasons << "Shares keyword: #{matching_kws.first}"
    end

    card_type_words = card["type_line"].to_s.split(/[\s\u2014\-]+/).map(&:downcase)
    if (card_type_words & liked_type_words).any?
      score   += 1
      reasons << "Matches card type"
    end

    card_cmc = card["cmc"].to_i
    if cmc_min && cmc_max && card_cmc >= cmc_min && card_cmc <= cmc_max
      score   += 1
      reasons << "Similar mana cost"
    end

    { card: card, score: score, reasons: reasons }
  end
end
