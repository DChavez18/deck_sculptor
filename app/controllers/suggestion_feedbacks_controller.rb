class SuggestionFeedbacksController < ApplicationController
  before_action :set_deck

  def create
    card     = find_or_create_card_for_feedback
    feedback = @deck.suggestion_feedbacks.find_or_initialize_by(scryfall_id: params[:scryfall_id])
    feedback.card = card if card
    feedback.update!(card_name: params[:card_name], feedback: params[:feedback])

    if params[:feedback] == "down"
      # Blacklist FIRST before any other work
      @deck.blacklist_card(params[:scryfall_id])

      # Get a replacement from already-cached suggestions only
      # Use ScryfallService color identity search — fast, no EDHREC/CardCognition
      replacement = find_replacement_card

      streams = [ turbo_stream.remove("suggestion-#{params[:scryfall_id]}") ]
      if replacement
        feedbacks_by_id = @deck.suggestion_feedbacks.index_by(&:scryfall_id)
        streams << turbo_stream.append(
          "suggestions-grid",
          partial: "decks/suggestion_card",
          locals: { suggestion: replacement, deck: @deck, feedbacks: feedbacks_by_id }
        )
      end
      render turbo_stream: streams

    else
      # Thumbs up — run engines to find similar cards
      thumbed_up_ids  = @deck.suggestion_feedbacks.where(feedback: "up").pluck(:scryfall_id)
      commander_suggs = SuggestionEngine.new(@deck, liked_ids: thumbed_up_ids).suggestions
      intent_suggs    = IntentEngine.new(@deck, liked_ids: thumbed_up_ids).suggestions
      all_suggestions = MergeSuggestions.new(commander_suggs, intent_suggs).call
      new_cards = all_suggestions
        .reject { |s| blacklisted?(s, @deck) }
        .reject { |s| (s[:card]["id"] || s[:card]["scryfall_id"]) == params[:scryfall_id] }
        .first(3)

      feedbacks_by_id = @deck.suggestion_feedbacks.index_by(&:scryfall_id)
      streams = new_cards.map do |suggestion|
        turbo_stream.append(
          "suggestions-grid",
          partial: "decks/suggestion_card",
          locals: { suggestion: suggestion, deck: @deck, feedbacks: feedbacks_by_id }
        )
      end
      render turbo_stream: streams
    end
  end

  private

  def set_deck
    @deck = Deck.includes(:commander, :deck_cards).find(params[:deck_id])
  end

  def find_or_create_card_for_feedback
    card_hash = CardCache.fetch(params[:scryfall_id])
    card_hash ||= ScryfallService.new.find_card_by_id(params[:scryfall_id])
    return Card.find_by(scryfall_id: params[:scryfall_id]) unless card_hash

    Card.find_or_create_from_scryfall(card_hash)
  end

  def find_replacement_card
    colors = @deck.commander.raw_data&.dig("color_identity") || []
    service = ScryfallService.new
    candidates = service.cards_by_color_identity(colors)
    deck_ids = @deck.deck_cards.pluck(:scryfall_id).compact.to_set
    commander_id = @deck.commander.scryfall_id

    candidates
      .reject { |c| @deck.card_blacklisted?(c["id"].to_s) }
      .reject { |c| deck_ids.include?(c["id"]) }
      .reject { |c| c["id"] == commander_id }
      .first(1)
      .map { |c| { card: c, score: 1, reasons: [ "Within color identity" ], pool: "Color Identity" } }
      .first
  end
end
