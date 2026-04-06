require "rails_helper"

RSpec.describe "DeckChats", type: :request do
  let!(:commander) { create(:commander, raw_data: { "color_identity" => [ "U" ], "oracle_text" => "Draw a card." }) }
  let!(:deck)      { create(:deck, commander: commander) }

  let(:turbo_headers) { { "Accept" => "text/vnd.turbo-stream.html" } }
  let(:ai_response)   { "Here are some suggestions for your deck." }
  let(:advisor)       { instance_double(AiAdvisorService, chat: ai_response) }

  before do
    allow(AiAdvisorService).to receive(:new).and_return(advisor)
  end

  describe "POST /decks/:deck_id/deck_chats" do
    it "creates a user DeckChat record" do
      expect {
        post deck_deck_chats_path(deck),
          params: { message: "What should I cut?" },
          headers: turbo_headers
      }.to change(DeckChat, :count).by(2)

      user_chat = DeckChat.find_by(role: "user")
      expect(user_chat.content).to eq("What should I cut?")
      expect(user_chat.deck).to eq(deck)
    end

    it "creates an assistant DeckChat record with the AI response" do
      post deck_deck_chats_path(deck),
        params: { message: "What should I cut?" },
        headers: turbo_headers

      ai_chat = DeckChat.find_by(role: "assistant")
      expect(ai_chat.content).to eq(ai_response)
      expect(ai_chat.deck).to eq(deck)
    end

    it "responds with a Turbo Stream" do
      post deck_deck_chats_path(deck),
        params: { message: "What should I cut?" },
        headers: turbo_headers

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    end

    it "appends both messages to chat-history" do
      post deck_deck_chats_path(deck),
        params: { message: "What should I cut?" },
        headers: turbo_headers

      expect(response.body).to include('action="append"')
      expect(response.body).to include("chat-history")
    end

    it "replaces the chat-input partial" do
      post deck_deck_chats_path(deck),
        params: { message: "What should I cut?" },
        headers: turbo_headers

      expect(response.body).to include('action="replace"')
      expect(response.body).to include("chat-input")
    end

    it "passes the message to AiAdvisorService" do
      expect(advisor).to receive(:chat).with("What should I cut?")

      post deck_deck_chats_path(deck),
        params: { message: "What should I cut?" },
        headers: turbo_headers
    end
  end
end
