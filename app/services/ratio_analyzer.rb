class RatioAnalyzer
  TARGETS = {
    ramp:     10,
    draw:     10,
    removal:  8,
    land:     36,
    creature: 25
  }.freeze

  CATEGORY_MAP = {
    "ramp"     => :ramp,
    "draw"     => :draw,
    "removal"  => :removal,
    "land"     => :land,
    "creature" => :creature
  }.freeze

  def initialize(deck)
    @deck = deck
  end

  def report
    actuals = compute_actuals

    TARGETS.each_with_object({}) do |(bucket, target), hash|
      actual = actuals[bucket] || 0
      hash[bucket] = {
        actual:          actual,
        target:          target,
        cut_suggestions: cut_suggestions_for(bucket, actual, target)
      }
    end
  end

  private

  def compute_actuals
    counts = Hash.new(0)
    @deck.deck_cards.each do |dc|
      card_hash = build_card_hash(dc)
      CardCategorizer.new(card_hash).all_roles.each do |role|
        bucket = category_to_bucket(role)
        counts[bucket] += dc.quantity if bucket
      end
    end
    counts
  end

  def build_card_hash(deck_card)
    {
      "type_line"   => deck_card.type_line.to_s,
      "oracle_text" => deck_card.oracle_text.to_s,
      "keywords"    => Array(deck_card.raw_data&.dig("keywords")),
      "card_faces"  => Array(deck_card.raw_data&.dig("card_faces"))
    }
  end

  def category_to_bucket(category)
    CATEGORY_MAP[category]
  end

  def cut_suggestions_for(bucket, actual, target)
    return [] unless actual > target

    category_name = CATEGORY_MAP.key(bucket)
    cards_in_category = @deck.deck_cards.select { |dc| dc.category == category_name }

    cards_in_category
      .sort_by { |dc| -dc.cmc.to_f }
      .first(3)
      .map { |dc| { name: dc.card_name, cmc: dc.cmc.to_i } }
  end
end
