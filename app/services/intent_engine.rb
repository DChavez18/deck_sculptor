require "set"

class IntentEngine
  BUDGET_LIMITS = {
    "casual"    => 1.00,
    "optimized" => 5.00
    # competitive / nil → no price filter
  }.freeze

  # Maps a keyword matched against win_condition to [pool_label, oracle_tag] pairs
  WIN_CONDITION_POOLS = {
    "combat"    => [
      [ "Win Condition", "attack-trigger" ],
      [ "Win Condition", "combat-ramp" ]
    ],
    "combo"     => [
      [ "Combo", "tutor" ],
      [ "Combo", "graveyard-recursion" ]
    ],
    "control"   => [
      [ "Removal", "counter-spell" ],
      [ "Removal", "removal" ],
      [ "Board Wipes", "boardwipe" ]
    ],
    "tokens"    => [
      [ "Win Condition", "token-generation" ]
    ],
    "graveyard" => [
      [ "Win Condition", "graveyard-recursion" ]
    ]
  }.freeze

  def initialize(deck, liked_ids: [])
    @deck      = deck
    @liked_ids = liked_ids
  end

  def suggestions
    service     = ScryfallService.new
    colors      = commander_colors
    budget_opts = budget_options

    raw = fetch_all_pools(service, colors, budget_opts)

    # Deduplicate across pools: keep highest score for each card
    best = {}
    raw.each do |entry|
      id = entry[:card]["id"]
      best[id] = entry if !best[id] || entry[:score] > best[id][:score]
    end

    best.values
        .reject { |s| excluded_from_suggestions?(s) }
        .sort_by { |s| -s[:score] }
        .first(20)
  end

  private

  def excluded_from_suggestions?(suggestion)
    card = suggestion[:card]
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

  def commander_colors
    raw = @deck.commander.raw_data.presence || {}
    colors = raw["color_identity"] || []
    colors.empty? ? [ "C" ] : colors
  end

  def budget_options
    limit = BUDGET_LIMITS[@deck.budget]
    limit ? { budget: limit } : {}
  end

  def fetch_all_pools(service, colors, budget_opts)
    entries = []

    # All decks get ramp + card draw staples
    fetch_tagged(service, "ramp", colors, budget_opts).each do |card|
      entries << build_entry(card, "Staple", "ramp")
    end
    fetch_tagged(service, "draw-card", colors, budget_opts).each do |card|
      entries << build_entry(card, "Card Draw", "draw-card")
    end

    # Win-condition-specific pools
    win = @deck.win_condition.to_s.downcase
    WIN_CONDITION_POOLS.each do |keyword, pool_tag_pairs|
      next unless win.include?(keyword)

      pool_tag_pairs.each do |pool_label, tag|
        fetch_tagged(service, tag, colors, budget_opts).each do |card|
          entries << build_entry(card, pool_label, tag)
        end
      end
    end

    entries
  end

  def fetch_tagged(service, tag, colors, opts)
    service.cards_by_function(tag, colors, opts)
  rescue StandardError => e
    Rails.logger.error("IntentEngine fetch_tagged(#{tag}) error: #{e.message}")
    []
  end

  def build_entry(card, pool_label, tag)
    score   = 2  # base: card is in a relevant intent pool
    reasons = [ "Intent: #{pool_label}" ]

    bonus = playstyle_modifier(card, tag)
    if bonus > 0
      score   += bonus
      reasons << "Matches playstyle"
    end

    theme_result = theme_boost(card)
    if theme_result[:score] > 0
      score   += theme_result[:score]
      reasons.concat(theme_result[:reasons])
    end

    if within_color_identity?(card)
      score   += 1
      reasons << "Within color identity"
    end

    liked_score, liked_reason = liked_boost(card)
    if liked_score > 0
      score   += liked_score
      reasons << liked_reason
    end

    { card: card, score: score, reasons: reasons, pool: pool_label }
  end

  def playstyle_modifier(card, tag)
    case @deck.archetype.to_s
    when "aggro"
      card["cmc"].to_f <= 2 ? 1 : 0
    when "control"
      %w[removal counter-spell boardwipe].include?(tag) ? 1 : 0
    when "grind"
      tag == "draw-card" ? 1 : 0
    else
      0
    end
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

  def within_color_identity?(card)
    commander_raw    = @deck.commander.raw_data.presence || {}
    commander_colors = Set.new(commander_raw["color_identity"] || [])
    card_colors      = Set.new(card["color_identity"] || [])
    card_colors.subset?(commander_colors)
  end
end
