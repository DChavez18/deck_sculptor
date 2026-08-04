require "uri"

class ScryfallService
  BASE_URL = "https://api.scryfall.com"
  RATE_LIMIT_DELAY = 0.15
  MAX_RETRIES = 3
  RETRY_BACKOFF = 1.0
  COLLECTION_BATCH_SIZE = 75

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
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    cached = CardCache.fetch(scryfall_id)
    if cached
      elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round
      Rails.logger.info(
        "[INSTR scryfall_find_by_id] cache_hit=true scryfall_id=#{scryfall_id} elapsed_ms=#{elapsed}"
      )
      return cached
    end

    response = get_request("/cards/#{scryfall_id}")
    return nil unless success?(response)

    card = parse_body(response)
    CardCache.store(card["id"], card["name"], card)
    elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round
    Rails.logger.info(
      "[INSTR scryfall_find_by_id] cache_hit=false scryfall_id=#{scryfall_id} elapsed_ms=#{elapsed}"
    )
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

  def find_cards_by_names(names)
    return {} if names.empty?

    results = {}
    names.each_slice(COLLECTION_BATCH_SIZE) { |batch| fetch_collection_batch(batch, results) }
    results
  end

  private

  def get_request(path, params = {})
    url = build_url(path, params)
    response = nil

    (MAX_RETRIES + 1).times do |attempt|
      sleep(RATE_LIMIT_DELAY)
      response = HTTParty.get(url)
      break unless rate_limited?(response)

      sleep(RETRY_BACKOFF * (attempt + 1))
    end

    response
  rescue StandardError => e
    Rails.logger.error("ScryfallService error: #{e.message}")
    nil
  end

  def post_request(path, body)
    HTTParty.post("#{BASE_URL}#{path}", body: body.to_json, headers: { "Content-Type" => "application/json" })
  rescue StandardError => e
    Rails.logger.error("ScryfallService error: #{e.message}")
    nil
  end

  def fetch_collection_batch(batch, results)
    response = post_request("/cards/collection", identifiers: batch.map { |name| { name: name } })

    unless success?(response)
      fetch_fuzzy_fallback(batch, results)
      return
    end

    cards   = parse_body(response)["data"] || []
    matched = store_and_map_collection_results(batch, cards, results)
    fetch_fuzzy_fallback(batch - matched, results)
  end

  def store_and_map_collection_results(batch, cards, results)
    matched = []

    cards.each do |card|
      CardCache.store(card["id"], card["name"], card)
      original = batch.find { |name| name.casecmp?(card["name"]) }
      next unless original

      results[original] = card
      matched << original
    end

    matched
  end

  def fetch_fuzzy_fallback(names, results)
    names.each do |name|
      card = find_card_by_name(name)
      results[name] = card if card
    end
  end

  def rate_limited?(response)
    response && response.code == 429
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
