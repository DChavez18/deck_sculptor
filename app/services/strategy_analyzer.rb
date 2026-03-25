class StrategyAnalyzer
  ALL_THEMES = (
    ArchetypeDetector::COMBO_KEYWORDS +
    ArchetypeDetector::AGGRO_KEYWORDS +
    ArchetypeDetector::CONTROL_KEYWORDS +
    ArchetypeDetector::STAX_KEYWORDS
  ).freeze

  ARCHETYPE_DESCRIPTIONS = {
    "combo"     => "assembling powerful combinations to win through infinite loops or game-ending sequences",
    "aggro"     => "pressing an aggressive attack with fast creatures and pump effects",
    "control"   => "controlling the board through counterspells, removal, and card advantage",
    "stax"      => "slowing opponents down with tax effects and restrictive permanents",
    "midrange"  => "playing a balanced game with efficient threats and flexible answers",
    "goodstuff" => "leveraging individually powerful cards across multiple strategies"
  }.freeze

  def initialize(deck)
    @deck = deck
  end

  def report
    {
      detected_archetype: detected_archetype,
      color_gaps:         color_gaps,
      strategy_summary:   strategy_summary,
      key_themes:         key_themes
    }
  end

  private

  def detected_archetype
    @detected_archetype ||= ArchetypeDetector.new(@deck).detect
  end

  def color_gaps
    @color_gaps ||= ColorGapAnalyzer.new(@deck).analyze
  end

  def strategy_summary
    commander_name = @deck.commander.name
    archetype      = detected_archetype || "goodstuff"
    description    = ARCHETYPE_DESCRIPTIONS.fetch(archetype, ARCHETYPE_DESCRIPTIONS["goodstuff"])
    themes         = key_themes.first(2).join(" and ")

    summary = "#{commander_name} leads a #{archetype} deck focused on #{description}."
    summary += " Key themes include #{themes}." if themes.present?
    summary
  end

  def key_themes
    @key_themes ||= begin
      oracle_text = @deck.deck_cards.pluck(:oracle_text).join(" ").downcase

      ALL_THEMES
        .uniq
        .map { |theme| [ theme, oracle_text.scan(theme.downcase).count ] }
        .select { |_, count| count > 0 }
        .sort_by { |_, count| -count }
        .first(5)
        .map(&:first)
    end
  end
end
