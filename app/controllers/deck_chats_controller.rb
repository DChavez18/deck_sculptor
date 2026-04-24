class DeckChatsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_deck

  def create
    user_chat = @deck.deck_chats.create!(role: "user", content: params[:message])
    response  = AiAdvisorService.new(@deck).chat(params[:message])
    ai_chat   = @deck.deck_chats.create!(role: "assistant", content: response)

    render turbo_stream: [
      turbo_stream.append("chat-history",
        partial: "deck_chats/message",
        locals: { chat: user_chat }),
      turbo_stream.append("chat-history",
        partial: "deck_chats/message",
        locals: { chat: ai_chat }),
      turbo_stream.replace("chat-input",
        partial: "deck_chats/input",
        locals: { deck: @deck })
    ]
  end

  private

  def set_deck
    @deck = Deck.includes(:commander, :deck_cards, :suggestion_feedbacks, :deck_chats).find(params[:deck_id])
  end
end
