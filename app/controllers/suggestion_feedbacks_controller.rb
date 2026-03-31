class SuggestionFeedbacksController < ApplicationController
  before_action :set_deck

  def create
    feedback = @deck.suggestion_feedbacks.find_or_initialize_by(scryfall_id: params[:scryfall_id])
    feedback.update!(card_name: params[:card_name], feedback: params[:feedback])

    # Feedback is saved before building the blacklist so the just-acted-on card is always excluded.
    thumbed_up_ids = @deck.suggestion_feedbacks.where(feedback: "up").pluck(:scryfall_id)

    commander_suggs = SuggestionEngine.new(@deck, liked_ids: thumbed_up_ids).suggestions
    intent_suggs    = IntentEngine.new(@deck, liked_ids: thumbed_up_ids).suggestions
    all_suggestions = MergeSuggestions.new(commander_suggs, intent_suggs).call
    eligible        = all_suggestions.reject { |s| blacklisted?(s, @deck) }

    if params[:feedback] == "down"
      replacement = eligible.first

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
      new_cards       = eligible.first(3)
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
end
