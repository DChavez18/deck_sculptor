require "set"

class ComboFinderService
  BASE_URL = "https://backend.commanderspellbook.com/api/v1/variants/"

  def find_combos(deck_card_names)
    return [] if deck_card_names.blank?

    fetch_results(deck_card_names.first).map { |r| parse_combo(r) }
  end

  def near_miss_combos(deck_card_names)
    return [] if deck_card_names.blank?

    results       = fetch_results(deck_card_names.first)
    deck_name_set = Set.new(deck_card_names.map(&:downcase))

    near_misses = results.filter_map do |r|
      combo       = parse_combo(r)
      combo_cards = combo[:cards]
      next if combo_cards.size < 2

      matched = combo_cards.count { |c| deck_name_set.include?(c.downcase) }
      next unless matched == combo_cards.size - 1

      missing = combo_cards.find { |c| !deck_name_set.include?(c.downcase) }
      { combo: combo, missing_card: missing }
    end

    near_misses.first(5)
  rescue StandardError => e
    Rails.logger.error("ComboFinderService near_miss_combos error: #{e.message}")
    []
  end

  private

  def fetch_results(commander_name)
    @results ||= {}
    @results[commander_name] ||= begin
      response = HTTParty.get(BASE_URL, query: { q: "card:#{commander_name}" })
      return [] unless response&.code == 200

      data = JSON.parse(response.body)
      data["results"] || []
    rescue StandardError => e
      Rails.logger.error("ComboFinderService error: #{e.message}")
      []
    end
  end

  def parse_combo(result)
    cards       = (result["uses"] || []).filter_map { |u| u.dig("card", "name") }
    result_text = (result["produces"] || []).map { |p| p.dig("feature", "name") }.compact.join(", ")
    steps       = result["description"] || ""

    { cards: cards, result: result_text, steps: steps }
  end
end
