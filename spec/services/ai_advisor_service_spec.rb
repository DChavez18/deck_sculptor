require "rails_helper"

RSpec.describe AiAdvisorService, type: :service do
  let(:commander) do
    create(:commander,
      name: "Atraxa, Praetors' Voice",
      raw_data: {
        "color_identity" => %w[B G U W],
        "oracle_text"    => "Flying, vigilance, deathtouch, lifelink. Proliferate."
      })
  end
  let(:deck) { create(:deck, commander: commander, win_condition: "combo", budget: "optimized") }

  subject(:service) { described_class.new(deck) }

  let(:claude_api_url) { "https://api.anthropic.com/v1/messages" }

  let(:success_response_body) do
    {
      "content" => [ { "type" => "text", "text" => "Here are my suggestions for your deck." } ]
    }.to_json
  end

  let(:error_response_body) do
    { "error" => { "type" => "authentication_error", "message" => "invalid api key" } }.to_json
  end

  describe "#chat" do
    context "when the Claude API returns a successful response" do
      before do
        stub_request(:post, claude_api_url)
          .to_return(status: 200, body: success_response_body, headers: { "Content-Type" => "application/json" })
      end

      it "returns the text content from the response" do
        result = service.chat("What cards should I cut?")
        expect(result).to eq("Here are my suggestions for your deck.")
      end

      it "includes the commander name in the request body system prompt" do
        service.chat("Help me improve this deck.")
        expect(WebMock).to have_requested(:post, claude_api_url).with { |req|
          body = JSON.parse(req.body)
          body["system"].include?("Atraxa, Praetors' Voice")
        }
      end

      it "includes the deck card list in the system prompt" do
        create(:deck_card, deck: deck, card_name: "Sol Ring", category: "artifact", cmc: 1.0)
        service.chat("Any suggestions?")
        expect(WebMock).to have_requested(:post, claude_api_url).with { |req|
          body = JSON.parse(req.body)
          body["system"].include?("Sol Ring")
        }
      end

      it "includes the MTG-only restriction in the system prompt" do
        service.chat("Tell me about something.")
        expect(WebMock).to have_requested(:post, claude_api_url).with { |req|
          body = JSON.parse(req.body)
          body["system"].include?("You ONLY discuss Magic: The Gathering")
        }
      end

      it "sends the user message in the messages array" do
        service.chat("What are my weaknesses?")
        expect(WebMock).to have_requested(:post, claude_api_url).with { |req|
          body = JSON.parse(req.body)
          body["messages"].last == { "role" => "user", "content" => "What are my weaknesses?" }
        }
      end

      it "includes up to 10 prior deck_chats in conversation history" do
        create_list(:deck_chat, 3, deck: deck, role: "user", content: "Prior question")
        create_list(:deck_chat, 3, :assistant, deck: deck, content: "Prior answer")

        service.chat("New question")
        expect(WebMock).to have_requested(:post, claude_api_url).with { |req|
          body = JSON.parse(req.body)
          # history messages + the new user message
          body["messages"].size == 7
        }
      end
    end

    context "when the Claude API returns a non-200 response" do
      before do
        stub_request(:post, claude_api_url)
          .to_return(status: 401, body: error_response_body, headers: { "Content-Type" => "application/json" })
      end

      it "returns the fallback response" do
        result = service.chat("Help me.")
        expect(result).to eq("I'm having trouble connecting right now. Please try again in a moment.")
      end
    end

    context "when the API raises a network error" do
      before do
        stub_request(:post, claude_api_url).to_raise(StandardError.new("connection refused"))
      end

      it "returns the fallback response" do
        result = service.chat("Help me.")
        expect(result).to eq("I'm having trouble connecting right now. Please try again in a moment.")
      end
    end

    context "when the response body has no text content" do
      before do
        stub_request(:post, claude_api_url)
          .to_return(status: 200, body: { "content" => [] }.to_json,
                     headers: { "Content-Type" => "application/json" })
      end

      it "returns the fallback response" do
        result = service.chat("Help me.")
        expect(result).to eq("I'm having trouble connecting right now. Please try again in a moment.")
      end
    end
  end
end
