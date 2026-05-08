class NlPromptParserService
  CLAUDE_API_URL = "https://api.anthropic.com/v1/messages"
  MODEL          = "claude-sonnet-4-20250514"
  MAX_TOKENS     = 256
  CACHE_TTL      = 5.minutes

  def initialize(prompt)
    @prompt = prompt.to_s.strip
  end

  def parse
    return nil if @prompt.blank?

    cache_key = "nl_filter_spec/#{Digest::SHA256.hexdigest(@prompt.downcase)}"
    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { call_llm }
  end

  private

  def call_llm
    response = HTTParty.post(
      CLAUDE_API_URL,
      headers: {
        "x-api-key"         => api_key,
        "anthropic-version" => "2023-06-01",
        "Content-Type"      => "application/json"
      },
      body: {
        model:      MODEL,
        max_tokens: MAX_TOKENS,
        system:     system_prompt,
        messages:   [ { role: "user", content: @prompt } ]
      }.to_json
    )
    return nil unless response.success?

    text = response.parsed_response.dig("content", 0, "text").to_s.strip
    JSON.parse(text)
  rescue StandardError, JSON::ParserError
    nil
  end

  def system_prompt
    <<~PROMPT
      You are a Magic: The Gathering card search query parser. Parse the user's natural
      language query into a JSON filter spec. Return ONLY valid JSON with no prose or
      markdown. Do not wrap the JSON in code blocks.

      Filter spec schema:
      {
        "filter_type": "type" | "similarity" | "combo",
        "types": ["Creature", "Instant", "Sorcery", "Artifact", "Enchantment", "Planeswalker", "Land"],
        "subtypes": ["Elf", "Wizard", "Dragon", ...],
        "colors": ["W", "U", "B", "R", "G"],
        "max_cmc": integer or null,
        "min_cmc": integer or null,
        "keywords": ["Flying", "Haste", "Trample", ...],
        "reference_card": "exact card name" or null
      }

      Rules:
      - filter_type "type": for queries like "show me only elves", "green creatures", "cheap blue instants"
      - filter_type "similarity": for queries like "cards like Sol Ring", "similar to Rhystic Study"
      - filter_type "combo": for queries like "cards that combo with Thassa's Oracle", "combos with [card]"
      - For "cheap" infer max_cmc: 3; for "free" use max_cmc: 0; for "expensive" or "high CMC" use min_cmc: 5
      - Colors: W=white, U=blue, B=black, R=red, G=green
      - Omit null fields from the output; only include fields relevant to the query
      - If the query is not about Magic: The Gathering cards, return: {"filter_type": null}
    PROMPT
  end

  def api_key
    Rails.application.credentials.dig(:anthropic, :api_key)
  end
end
