class CurveAdvisor
  def initialize(deck)
    @deck = deck
  end

  def recommendations
    return [] if @deck.deck_cards.empty?

    recs     = []
    curve    = @deck.mana_curve
    avg      = compute_avg_cmc
    archetype = ArchetypeDetector.new(@deck).detect

    low_end = (curve[1] || 0) + (curve[2] || 0)
    if low_end < 8
      recs << "Your curve is light on early plays — consider adding more 1 and 2 drop cards"
    end

    high_end = curve.select { |cmc, _| cmc.to_i >= 5 }.values.sum
    if high_end > 15
      recs << "Your curve runs heavy — consider cutting some high CMC cards for more interaction"
    end

    if avg > 3.5
      recs << "Your average CMC is high for Commander — aim for closer to 3.0"
    elsif avg < 2.5 && archetype != "aggro"
      recs << "Your curve is very low — this may be intentional if you're playing aggro"
    end

    recs
  end

  private

  def compute_avg_cmc
    non_lands = @deck.deck_cards.reject { |dc| dc.category == "land" }
    return 0.0 if non_lands.empty?

    total_cmc   = non_lands.sum { |dc| dc.cmc.to_f * dc.quantity }
    total_cards = non_lands.sum(&:quantity)

    total_cards > 0 ? (total_cmc / total_cards).round(2) : 0.0
  end
end
