class AiAdvisorService
  CLAUDE_API_URL = "https://api.anthropic.com/v1/messages"
  MODEL          = "claude-sonnet-4-20250514"
  MAX_TOKENS     = 1024

  def initialize(deck)
    @deck = deck
  end

  def chat(message)
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
        messages:   conversation_history + [ { role: "user", content: message } ]
      }.to_json
    )
    return fallback_response unless response.success?

    response.parsed_response.dig("content", 0, "text") || fallback_response
  rescue StandardError
    fallback_response
  end

  private

  def system_prompt
    cards_by_category = @deck.deck_cards.group_by(&:category)
    card_lines = cards_by_category.map do |cat, cards|
      "#{cat.capitalize} (#{cards.size}): #{cards.map(&:card_name).join(', ')}"
    end.join("\n")

    liked_ids = @deck.suggestion_feedbacks.where(feedback: "up").pluck(:scryfall_id)
    liked_names = liked_ids.filter_map { |id|
      @deck.suggestion_feedbacks.find_by(scryfall_id: id)&.card_name
    }.first(5)

    <<~PROMPT
      You are an expert Magic: The Gathering deck advisor specializing in
      the Commander (EDH) format. You ONLY discuss Magic: The Gathering
      topics. If asked about anything unrelated to MTG, politely decline
      and redirect to deck-building questions.

      You are advising on this specific Commander deck:

      Commander: #{@deck.commander.name}
      Colors: #{@deck.commander.raw_data&.dig("color_identity")&.join(", ")}
      Commander oracle text: #{@deck.commander.raw_data&.dig("oracle_text")}

      Deck intent:
      - Win condition: #{@deck.win_condition.presence || "not specified"}
      - Playstyle: #{@deck.archetype.presence || "not specified"}
      - Budget: #{@deck.budget.presence || "not specified"}
      - Themes: #{@deck.themes.presence || "not specified"}
      - Bracket level: #{@deck.bracket_level}

      Current deck (#{@deck.deck_cards.count} cards):
      #{card_lines}

      Cards the player has liked: #{liked_names.any? ? liked_names.join(", ") : "none yet"}

      Commander format rules you must respect:
      - 100 card singleton deck (exactly 99 cards + commander)
      - All cards must be within the commander's color identity
      - No card may appear more than once (except basic lands)

      Guidelines:
      - Be concise and specific — no generic advice, always reference
        this deck's actual cards and commander
      - Never suggest cards outside the commander's color identity
      - Consider the bracket level when discussing power level
      - If suggesting cuts or additions, explain why in terms of this
        deck's strategy
      - Use bullet points for lists of suggestions
      - Keep responses under 300 words unless a detailed breakdown is
        explicitly requested
    PROMPT
  end

  def conversation_history
    @deck.deck_chats.order(:created_at).last(10).map do |chat|
      { role: chat.role, content: chat.content }
    end
  end

  def api_key
    Rails.application.credentials.dig(:anthropic, :api_key)
  end

  def fallback_response
    "I'm having trouble connecting right now. Please try again in a moment."
  end
end
