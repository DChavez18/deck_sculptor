class CardCategorizer
  def initialize(card)
    @card         = card
    @type_line    = card["type_line"].to_s
    @oracle_text  = card["oracle_text"].to_s
    @keywords     = Array(card["keywords"])
  end

  def category
    return "land"       if land?
    return "ramp"       if ramp?
    return "draw"       if draw?
    return "board_wipe" if board_wipe?
    return "removal"    if removal?
    return "tutor"      if tutor?
    return "protection" if protection?
    return "creature"   if @type_line.include?("Creature")

    type_fallback
  end

  def categories
    faces = card_faces
    if faces.any?
      faces.flat_map { |face| face_categories(face) }.uniq.compact
    else
      [ category ]
    end
  end

  def all_roles
    return categories if card_faces.any?
    return [ "land" ] if land?

    roles = []
    roles << "ramp"       if ramp?
    roles << "draw"       if draw?
    roles << "board_wipe" if board_wipe?
    roles << "removal"    if removal?
    roles << "tutor"      if tutor?
    roles << "protection" if protection?
    roles << "creature"   if @type_line.include?("Creature")
    roles << type_fallback if roles.empty?
    roles
  end

  private

  def land?
    @type_line.include?("Land")
  end

  def ramp?
    return true if @oracle_text.match?(/add \{/i)
    return true if @oracle_text.match?(/add one mana/i)
    return true if @oracle_text.match?(/add two mana/i)
    return true if @oracle_text.match?(/add three mana/i)
    return true if @oracle_text.match?(/search your library for (a |up to two |up to \d+ )?(basic )?land/i)
    return true if @oracle_text.match?(/put (a |that )?(land )?card (onto|into|on) the battlefield/i)
    return true if @oracle_text.match?(/you may play (an? )?additional land/i)
    return true if @keywords.any? { |k| k.casecmp?("Treasure") } || @type_line.include?("Food")
    return true if @oracle_text.match?(/spells you cast cost \{/i)
    return true if @oracle_text.match?(/abilities cost \{/i)

    false
  end

  def draw?
    return true if @oracle_text.match?(/draw (a card|cards|\d+ cards|two cards|three cards)/i)
    return true if @oracle_text.match?(/draws (a card|cards|\d+ cards)/i)
    return true if @oracle_text.match?(/each player draws/i)
    return true if @oracle_text.match?(/draw cards equal/i)
    return true if @oracle_text.match?(/look at the top \d+ cards/i)
    return true if @oracle_text.match?(/you may cast (the top|cards from the top)/i)

    false
  end

  def board_wipe?
    return true if @oracle_text.match?(/destroy all/i)
    return true if @oracle_text.match?(/exile all/i)
    return true if @oracle_text.match?(/return (all|each)/i)
    return true if @oracle_text.match?(/each player sacrifices/i)
    return true if @oracle_text.match?(/deals \d+ damage to each/i)
    return true if @oracle_text.match?(/each creature gets -/i)

    false
  end

  def removal?
    return true if @oracle_text.match?(/destroy target/i)
    return true if @oracle_text.match?(/exile target/i)
    return true if @oracle_text.match?(/return target (creature|artifact|enchantment|permanent|spell|nonland|land)/i)
    return true if @oracle_text.match?(/counter target/i)
    return true if @oracle_text.match?(/deals? \d+ damage to (any target|target creature|target player)/i)
    return true if @oracle_text.match?(/target player sacrifices/i)
    return true if @oracle_text.match?(/put target .* into (its owner's|their owner's) (hand|graveyard|library)/i)

    false
  end

  def tutor?
    return false if @oracle_text.match?(/search your library for (a |up to two |up to \d+ )?(basic )?land/i)

    return true if @oracle_text.match?(/search your library for (a card|an? (instant|sorcery|creature|artifact|enchantment|planeswalker))/i)
    return true if @oracle_text.match?(/search your library for (up to \d+ cards?)/i)

    false
  end

  def protection?
    return true if @oracle_text.match?(/hexproof/i)
    return true if @oracle_text.match?(/indestructible/i)
    return true if @oracle_text.match?(/shroud/i)
    return true if @oracle_text.match?(/protection from/i)
    return true if @oracle_text.match?(/can't be countered/i)
    return true if @oracle_text.match?(/untap target/i)

    false
  end

  def type_fallback
    downcased = @type_line.downcase
    %w[instant sorcery artifact enchantment planeswalker battle].each do |t|
      return t if downcased.include?(t)
    end
    "utility"
  end

  def card_faces
    Array(@card["card_faces"] || [])
  end

  def face_categories(face)
    cat = CardCategorizer.new(
      "type_line"   => face["type_line"].to_s,
      "oracle_text" => face["oracle_text"].to_s,
      "keywords"    => face["keywords"] || []
    ).category
    [ cat ].compact
  end
end
