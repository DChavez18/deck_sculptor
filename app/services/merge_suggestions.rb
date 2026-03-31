class MergeSuggestions
  # Merges results from SuggestionEngine and IntentEngine.
  # When the same card appears in both, the higher-score entry wins.
  # Commander engine results that have no :pool key are tagged "Commander Synergy".
  # Final result is sorted by score desc, capped at 30.

  def initialize(commander_suggestions, intent_suggestions)
    @commander = commander_suggestions
    @intent    = intent_suggestions
  end

  def call
    merged = {}

    @commander.each do |s|
      s = s.merge(pool: "Commander Synergy") unless s.key?(:pool)
      merged[s[:card]["id"]] = s
    end

    @intent.each do |s|
      id = s[:card]["id"]
      if merged[id]
        merged[id] = s[:score] > merged[id][:score] ? s : merged[id]
      else
        merged[id] = s
      end
    end

    merged.values.sort_by { |s| -s[:score] }.first(100)
  end
end
