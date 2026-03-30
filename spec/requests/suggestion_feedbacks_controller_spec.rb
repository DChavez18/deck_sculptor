require "rails_helper"

RSpec.describe "SuggestionFeedbacks", type: :request do
  let!(:commander) { create(:commander, raw_data: { "color_identity" => [ "U" ], "keywords" => [] }) }
  let!(:deck)      { create(:deck, commander: commander) }

  let(:scryfall_id) { "card-abc-123" }
  let(:card_name)   { "Sol Ring" }

  let(:suggestion_engine) { instance_double(SuggestionEngine) }
  let(:turbo_headers)     { { "Accept" => "text/vnd.turbo-stream.html" } }
  let(:new_card_suggestion) do
    {
      card: {
        "id"             => "new-card-1",
        "name"           => "Thran Dynamo",
        "type_line"      => "Artifact",
        "cmc"            => 4.0,
        "color_identity" => [],
        "keywords"       => [],
        "oracle_text"    => "{T}: Add {C}{C}{C}.",
        "image_uris"     => {}
      },
      score: 3,
      reasons: [ "Matches card type" ]
    }
  end

  before do
    allow(SuggestionEngine).to receive(:new).and_return(suggestion_engine)
    allow(suggestion_engine).to receive(:more_like).and_return([])
  end

  describe "POST /decks/:deck_id/suggestion_feedbacks" do
    context "thumbs down" do
      it "creates a feedback record with 'down'" do
        expect {
          post deck_suggestion_feedbacks_path(deck),
            params: { scryfall_id: scryfall_id, card_name: card_name, feedback: "down" },
            headers: turbo_headers
        }.to change(SuggestionFeedback, :count).by(1)

        expect(SuggestionFeedback.last.feedback).to eq("down")
      end

      it "responds with a Turbo Stream remove targeting the card wrapper" do
        post deck_suggestion_feedbacks_path(deck),
          params: { scryfall_id: scryfall_id, card_name: card_name, feedback: "down" },
          headers: turbo_headers

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("remove")
        expect(response.body).to include("suggestion-#{scryfall_id}")
      end
    end

    context "thumbs up" do
      it "creates a feedback record with 'up'" do
        expect {
          post deck_suggestion_feedbacks_path(deck),
            params: { scryfall_id: scryfall_id, card_name: card_name, feedback: "up" },
            headers: turbo_headers
        }.to change(SuggestionFeedback, :count).by(1)

        expect(SuggestionFeedback.last.feedback).to eq("up")
      end

      it "responds with a Turbo Stream append targeting suggestions-grid" do
        allow(suggestion_engine).to receive(:more_like).and_return([ new_card_suggestion ])

        post deck_suggestion_feedbacks_path(deck),
          params: { scryfall_id: scryfall_id, card_name: card_name, feedback: "up" },
          headers: turbo_headers

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("suggestions-grid")
      end

      it "calls more_like with all current thumbs-up scryfall IDs" do
        other_up = create(:suggestion_feedback, deck: deck, scryfall_id: "existing-up", feedback: "up")

        expect(suggestion_engine).to receive(:more_like).with(
          a_collection_containing_exactly("existing-up", scryfall_id)
        ).and_return([])

        post deck_suggestion_feedbacks_path(deck),
          params: { scryfall_id: scryfall_id, card_name: card_name, feedback: "up" },
          headers: turbo_headers
      end
    end

    context "upsert behavior" do
      it "updates existing feedback instead of creating a duplicate" do
        existing = create(:suggestion_feedback, deck: deck, scryfall_id: scryfall_id, feedback: "up")

        expect {
          post deck_suggestion_feedbacks_path(deck),
            params: { scryfall_id: scryfall_id, card_name: card_name, feedback: "down" },
            headers: turbo_headers
        }.not_to change(SuggestionFeedback, :count)

        expect(existing.reload.feedback).to eq("down")
      end
    end
  end
end
