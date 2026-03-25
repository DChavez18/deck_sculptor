class ArchetypeDetector
  MINIMUM_CARDS = 10

  COMBO_KEYWORDS   = %w[tutor infinite untap storm copy combo].freeze
  AGGRO_KEYWORDS   = %w[haste attack token +1/+1].freeze
  CONTROL_KEYWORDS = %w[counter destroy exile draw wipe].freeze
  STAX_KEYWORDS    = [ "tax", "can't", "prevent", "each opponent" ].freeze

  def initialize(deck)
    @deck = deck
  end

  def detect
    return nil if @deck.deck_cards.sum(:quantity) < MINIMUM_CARDS

    scores = {
      "combo"   => score_combo,
      "aggro"   => score_aggro,
      "control" => score_control,
      "stax"    => score_stax
    }

    best_archetype, best_score = scores.max_by { |_, v| v }
    return "goodstuff" if best_score == 0

    best_archetype
  end

  private

  def all_oracle_text
    @all_oracle_text ||= @deck.deck_cards.pluck(:oracle_text).join(" ").downcase
  end

  def keyword_hits(keywords)
    keywords.sum { |kw| all_oracle_text.scan(kw.downcase).count }
  end

  def category_count(category)
    @deck.deck_cards.where(category: category).sum(:quantity)
  end

  def score_combo
    keyword_hits(COMBO_KEYWORDS) * 2 + category_count("combo")
  end

  def score_aggro
    hits = keyword_hits(AGGRO_KEYWORDS)
    return 0 if hits == 0

    creature_score = [ category_count("creature") / 3, 5 ].min
    hits * 2 + creature_score + (@deck.avg_cmc < 3.0 && @deck.avg_cmc > 0 ? 3 : 0)
  end

  def score_control
    keyword_hits(CONTROL_KEYWORDS) * 2 + category_count("removal")
  end

  def score_stax
    keyword_hits(STAX_KEYWORDS) * 3
  end
end
