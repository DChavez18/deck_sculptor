require "set"

class UpgradeFinder
  SCORE_THRESHOLD  = 6
  CLAUDE_API_URL   = "https://api.anthropic.com/v1/messages"
  CLAUDE_MODEL     = "claude-sonnet-4-6"
  CLAUDE_TOKENS    = 150
  REASON_CACHE_TTL = 1.hour

  def initialize(deck)
    @deck = deck
  end

  def upgrades
    return [] if @deck.deck_cards.empty?

    deck_scryfall_ids   = @deck.deck_cards.pluck(:scryfall_id).compact.to_set
    commander_keywords  = Set.new((@deck.commander.raw_data || {})["keywords"] || [])
    theme_keywords      = @deck.themes.to_s.split(",").map(&:strip).reject(&:blank?)
    deck_cards_by_cat   = @deck.deck_cards.group_by(&:category)

    scored = SuggestionEngine.new(@deck).suggestions
                             .select { |s| s[:score] >= SCORE_THRESHOLD }
                             .reject { |s| deck_scryfall_ids.include?(s[:card]["id"]) }

    results = []

    scored.each do |suggestion|
      break if results.size >= 5

      card     = suggestion[:card]
      category = CardCategorizer.new(card).category
      pool     = deck_cards_by_cat[category] || []
      next if pool.empty?

      suggestion_keywords = Set.new(card["keywords"] || [])
      suggestion_oracle   = card["oracle_text"].to_s.downcase

      shared_commander_kw = suggestion_keywords & commander_keywords
      matched_themes      = theme_keywords.select { |kw| suggestion_oracle.include?(kw.downcase) }

      next if shared_commander_kw.empty? && matched_themes.empty?

      deck_card = pool.find do |dc|
        dc_keywords   = Set.new((dc.raw_data.is_a?(Hash) ? dc.raw_data["keywords"] : nil) || [])
        dc_oracle     = dc.oracle_text.to_s.downcase
        no_kw_overlap = (dc_keywords & commander_keywords).empty?
        no_theme      = matched_themes.none? { |kw| dc_oracle.include?(kw.downcase) }
        no_kw_overlap && no_theme
      end

      next unless deck_card

      pool.delete(deck_card)
      results << {
        current_card: deck_card,
        upgrade_card: card,
        reason:       generate_reason(deck_card, suggestion, shared_commander_kw, matched_themes)
      }
    end

    results
  end

  private

  def generate_reason(deck_card, suggestion, shared_keywords, matching_themes)
    card           = suggestion[:card]
    commander_name = @deck.commander.name
    cache_key      = "upgrade_reason/#{commander_name}/#{deck_card.card_name}/#{card['name']}"

    result = Rails.cache.fetch(cache_key, expires_in: REASON_CACHE_TTL, skip_nil: true) do
      call_reason_api(deck_card, card)
    end

    result.presence || build_reason(deck_card, shared_keywords, matching_themes)
  rescue StandardError
    build_reason(deck_card, shared_keywords, matching_themes)
  end

  def call_reason_api(deck_card, card)
    response = HTTParty.post(
      CLAUDE_API_URL,
      headers: {
        "x-api-key"         => api_key,
        "anthropic-version" => "2023-06-01",
        "Content-Type"      => "application/json"
      },
      body: {
        model:      CLAUDE_MODEL,
        max_tokens: CLAUDE_TOKENS,
        messages:   [ { role: "user", content: reason_prompt(deck_card, card) } ]
      }.to_json
    )
    return nil unless response.success?

    response.parsed_response.dig("content", 0, "text").to_s.strip.presence
  rescue StandardError
    nil
  end

  def reason_prompt(deck_card, card)
    commander        = @deck.commander
    commander_oracle = (commander.raw_data || {})["oracle_text"].to_s.truncate(300)
    <<~PROMPT.strip
      Commander: #{commander.name}
      Commander oracle text: #{commander_oracle}
      Deck themes: #{@deck.themes.to_s.presence || "none"}

      Card being replaced: #{deck_card.card_name}
      Replaced card oracle text: #{deck_card.oracle_text.to_s.truncate(200)}

      Suggested upgrade: #{card["name"]} (mana cost: #{card["mana_cost"]})
      Upgrade oracle text: #{card["oracle_text"].to_s.truncate(200)}

      In 1-2 sentences, explain specifically why #{card["name"]} is a meaningful upgrade over #{deck_card.card_name} for this commander deck. Focus on card mechanics and synergies, not generic advice. No preamble.
    PROMPT
  end

  def build_reason(deck_card, shared_keywords, matching_themes)
    parts = []
    parts << "shares #{shared_keywords.first} with your commander" if shared_keywords.any?
    parts << "matches your #{matching_themes.first} theme"         if matching_themes.any?
    "Replaces #{deck_card.card_name} — #{parts.join(' and ')}"
  end

  def api_key
    Rails.application.credentials.dig(:anthropic, :api_key)
  end
end
