class EdhrecService
  BASE_URL = "https://json.edhrec.com/pages/commanders"

  def commander_data(commander_name)
    slug      = name_to_slug(commander_name)
    cache_key = "edhrec:#{slug}"

    cached = CardCache.fetch(cache_key)
    return cached if cached

    response = HTTParty.get("#{BASE_URL}/#{slug}.json")
    return nil unless response&.code == 200

    data = JSON.parse(response.body)
    CardCache.store(cache_key, commander_name, data)
    data
  rescue StandardError => e
    Rails.logger.error("EdhrecService error: #{e.message}")
    nil
  end

  def top_cards(commander_name)
    data = commander_data(commander_name)
    return [] unless data.is_a?(Hash)

    card_list = data["cardlist"] || []
    card_list.first(20).filter_map { |c| c["name"] }
  rescue StandardError
    []
  end

  def top_cards_with_details(commander_name)
    data = commander_data(commander_name)
    return [] unless data.is_a?(Hash)

    card_list = data["cardlist"] || []
    card_list.first(10).filter_map do |c|
      next unless c["name"].present?
      {
        name:     c["name"],
        category: infer_category(c["type"].to_s),
        reason:   "Popular with #{commander_name}"
      }
    end
  rescue StandardError
    []
  end

  def name_to_slug(name)
    name
      .downcase
      .gsub(/[^a-z0-9\s-]/, "")
      .gsub(/\s+/, "-")
      .squeeze("-")
      .strip
  end

  private

  def infer_category(type_line)
    return "creature"    if type_line.include?("Creature")
    return "instant"     if type_line.include?("Instant")
    return "sorcery"     if type_line.include?("Sorcery")
    return "enchantment" if type_line.include?("Enchantment")
    return "artifact"    if type_line.include?("Artifact")
    return "land"        if type_line.include?("Land")

    "other"
  end
end
