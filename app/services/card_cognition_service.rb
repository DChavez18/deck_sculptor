class CardCognitionService
  BASE_URL = "https://api.cardcognition.com"
  RATE_LIMIT_DELAY = 0.1

  def initialize(commander_name)
    @commander_slug = slugify(commander_name)
  end

  def suggestions(count: 50)
    cache_key = "cardcognition_#{@commander_slug}"
    cached = CardCache.fetch(cache_key)
    return cached if cached

    sleep(RATE_LIMIT_DELAY)
    response = HTTParty.get("#{BASE_URL}/#{@commander_slug}/suggestions/#{count}")
    return [] unless response&.code == 200

    data = JSON.parse(response.body)
    CardCache.store(cache_key, @commander_slug, data)
    data
  rescue StandardError => e
    Rails.logger.error("CardCognitionService error: #{e.message}")
    []
  end

  private

  def slugify(name)
    name
      .downcase
      .gsub(/[',]/, "")
      .gsub(/\s+/, "-")
      .squeeze("-")
  end
end
