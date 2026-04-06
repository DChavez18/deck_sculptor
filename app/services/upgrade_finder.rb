require "set"

class UpgradeFinder
  SCORE_THRESHOLD = 6

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
        reason:       build_reason(deck_card, shared_commander_kw, matched_themes)
      }
    end

    results
  end

  private

  def build_reason(deck_card, shared_keywords, matching_themes)
    parts = []
    parts << "shares #{shared_keywords.first} with your commander" if shared_keywords.any?
    parts << "matches your #{matching_themes.first} theme"         if matching_themes.any?
    "Replaces #{deck_card.card_name} — #{parts.join(' and ')}"
  end
end
