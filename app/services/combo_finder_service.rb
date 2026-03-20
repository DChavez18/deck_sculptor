class ComboFinderService
  BASE_URL = "https://backend.commanderspellbook.com/api/v1/variants/"

  def find_combos(deck_card_names)
    return [] if deck_card_names.blank?

    commander_name = deck_card_names.first
    response = HTTParty.get(BASE_URL, query: { q: "card:#{commander_name}" })
    return [] unless response&.code == 200

    data    = JSON.parse(response.body)
    results = data["results"] || []
    results.map { |r| parse_combo(r) }
  rescue StandardError => e
    Rails.logger.error("ComboFinderService error: #{e.message}")
    []
  end

  private

  def parse_combo(result)
    cards  = (result["uses"] || []).filter_map { |u| u.dig("card", "name") }
    result_text = (result["produces"] || []).map { |p| p.dig("feature", "name") }.compact.join(", ")
    steps  = result["description"] || ""

    { cards: cards, result: result_text, steps: steps }
  end
end
