class CardCategorizer
  CATEGORIES = {
    "Land"        => "land",
    "Creature"    => "creature",
    "Instant"     => "instant",
    "Sorcery"     => "sorcery",
    "Enchantment" => "enchantment",
    "Artifact"    => "artifact",
    "Planeswalker" => "planeswalker"
  }.freeze

  def initialize(card)
    @type_line = card["type_line"].to_s
  end

  def category
    return "utility" if @type_line.include?("Tribal")

    CATEGORIES.each do |type_word, category|
      return category if @type_line.include?(type_word)
    end
    "utility"
  end
end
