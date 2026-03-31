require "uri"

class ScryfallService
  BASE_URL = "https://api.scryfall.com"
  RATE_LIMIT_DELAY = 0.1

  def search_commander(name)
    query = "name:#{name} is:commander legal:commander"
    response = get_request("/cards/search", q: query)
    parse_list_response(response)
  end

  def find_commander(name)
    cached = CardCache.fetch_by_name(name)
    return cached if cached

    response = get_request("/cards/named", fuzzy: name)
    return nil unless success?(response)

    card = parse_body(response)
    CardCache.store(card["id"], card["name"], card)
    card
  end

  def search_cards(query)
    response = get_request("/cards/search", q: "#{query} -is:digital game:paper")
    parse_list_response(response)
  end

  def find_card_by_name(name)
    cached = CardCache.fetch_by_name(name)
    return cached if cached

    response = get_request("/cards/named", fuzzy: name)
    return nil unless success?(response)

    card = parse_body(response)
    CardCache.store(card["id"], card["name"], card)
    card
  end

  def find_card_by_id(scryfall_id)
    cached = CardCache.fetch(scryfall_id)
    return cached if cached

    response = get_request("/cards/#{scryfall_id}")
    return nil unless success?(response)

    card = parse_body(response)
    CardCache.store(card["id"], card["name"], card)
    card
  end

  def cards_by_color_identity(colors, options = {})
    query = build_color_identity_query(colors, options)
    response = get_request("/cards/search", q: query)
    parse_list_response(response)
  end

  def cards_by_function(tag, color_identity, options = {})
    cache_key = "otag_#{tag}_#{color_identity.sort.join.downcase}"
    cache_key += "_#{options[:budget]}" if options[:budget]

    cached = CardCache.fetch(cache_key)
    return cached if cached

    color_string = color_identity.empty? ? "c" : color_identity.map(&:downcase).sort.join
    parts = [ "oracletag:#{tag}", "id<=#{color_string}", "legal:commander", "-is:digital", "game:paper" ]
    parts << "usd<=#{options[:budget]}" if options[:budget]

    response = get_request("/cards/search", q: parts.join(" "))
    result   = parse_list_response(response)

    CardCache.store(cache_key, cache_key, result) unless result.empty?
    result
  end

  def commander_suggestions(commander_card)
    colors = commander_card["color_identity"] || []
    keywords = commander_card["keywords"] || []

    query = build_suggestion_query(colors, keywords)
    response = get_request("/cards/search", q: query)
    parse_list_response(response)
  end

  private

  def get_request(path, params = {})
    sleep(RATE_LIMIT_DELAY)
    url = build_url(path, params)
    HTTParty.get(url)
  rescue StandardError => e
    Rails.logger.error("ScryfallService error: #{e.message}")
    nil
  end

  def build_url(path, params)
    return "#{BASE_URL}#{path}" if params.empty?

    "#{BASE_URL}#{path}?#{URI.encode_www_form(params)}"
  end

  def success?(response)
    response && response.code == 200
  end

  def parse_body(response)
    JSON.parse(response.body)
  end

  def parse_list_response(response)
    return [] unless success?(response)

    data = parse_body(response)
    data.is_a?(Hash) ? (data["data"] || []) : []
  end

  def build_color_identity_query(colors, options)
    color_string = colors.sort.join
    parts = [ "id<=#{color_string}", "legal:commander", "-is:digital", "game:paper" ]
    parts << "t:#{options[:type]}" if options[:type]
    options[:exclude_ids]&.each { |id| parts << "-id:#{id}" }
    parts.join(" ")
  end

  def build_suggestion_query(colors, keywords)
    color_string = colors.sort.join
    parts = [ "id<=#{color_string}" ]
    parts << "o:#{keywords.first}" if keywords.any?
    parts += [ "legal:commander", "-is:digital", "game:paper" ]
    parts.join(" ")
  end
end
