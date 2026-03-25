class ColorGapAnalyzer
  def initialize(deck)
    @deck = deck
  end

  def analyze
    {
      missing_colors:     missing_colors,
      off_color_cards:    off_color_cards,
      color_distribution: color_distribution
    }
  end

  private

  def commander_colors
    @commander_colors ||= @deck.commander.color_identity_array
  end

  def deck_card_colors
    @deck.deck_cards.map(&:color_identity_array)
  end

  def missing_colors
    represented = deck_card_colors.flatten.uniq
    commander_colors - represented
  end

  def off_color_cards
    @deck.deck_cards.select do |card|
      card_colors = card.color_identity_array
      next false if card_colors.empty?

      (card_colors - commander_colors).any?
    end
  end

  def color_distribution
    distribution = Hash.new(0)

    @deck.deck_cards.each do |card|
      card.color_identity_array.each do |color|
        distribution[color] += card.quantity
      end
    end

    distribution
  end
end
