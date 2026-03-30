class SuggestionFeedbacksController < ApplicationController
  before_action :set_deck

  def create
    feedback = @deck.suggestion_feedbacks.find_or_initialize_by(scryfall_id: params[:scryfall_id])
    feedback.update!(card_name: params[:card_name], feedback: params[:feedback])

    if params[:feedback] == "down"
      render turbo_stream: turbo_stream.remove("suggestion-#{params[:scryfall_id]}")
    else
      thumbed_up_ids   = @deck.suggestion_feedbacks.where(feedback: "up").pluck(:scryfall_id)
      new_suggestions  = SuggestionEngine.new(@deck).more_like(thumbed_up_ids)
      feedbacks_by_id  = @deck.suggestion_feedbacks.index_by(&:scryfall_id)

      streams = new_suggestions.map do |suggestion|
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
