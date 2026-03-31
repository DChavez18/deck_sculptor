require "rails_helper"

RSpec.describe "SuggestionFeedbacks", type: :request do
  let!(:commander) { create(:commander, raw_data: { "color_identity" => [ "U" ], "keywords" => [] }) }
  let!(:deck)      { create(:deck, commander: commander) }

  let(:scryfall_id) { "card-abc-123" }
  let(:card_name)   { "Sol Ring" }

  let(:suggestion_engine)  { instance_double(SuggestionEngine) }
  let(:intent_engine)      { instance_double(IntentEngine) }
  let(:merge_suggestions)  { instance_double(MergeSuggestions) }
  let(:turbo_headers)      { { "Accept" => "text/vnd.turbo-stream.html" } }
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
    allow(suggestion_engine).to receive(:suggestions).and_return([])
    allow(IntentEngine).to receive(:new).and_return(intent_engine)
    allow(intent_engine).to receive(:suggestions).and_return([])
    allow(MergeSuggestions).to receive(:new).and_return(merge_suggestions)
    allow(merge_suggestions).to receive(:call).and_return([])
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

      context "when a replacement card is available" do
        before do
          allow(merge_suggestions).to receive(:call).and_return([ new_card_suggestion ])
        end

        it "responds with both remove and append streams" do
          post deck_suggestion_feedbacks_path(deck),
            params: { scryfall_id: scryfall_id, card_name: card_name, feedback: "down" },
            headers: turbo_headers

          expect(response.media_type).to eq("text/vnd.turbo-stream.html")
          expect(response.body).to include("remove")
          expect(response.body).to include("suggestion-#{scryfall_id}")
          expect(response.body).to include("append")
          expect(response.body).to include("suggestions-grid")
        end

        it "builds replacement using liked_ids from existing thumbs-up feedback" do
          create(:suggestion_feedback, deck: deck, scryfall_id: "liked-card-1", feedback: "up")

          expect(SuggestionEngine).to receive(:new).with(
            deck, liked_ids: a_collection_containing_exactly("liked-card-1")
          ).and_return(suggestion_engine)
          expect(IntentEngine).to receive(:new).with(
            deck, liked_ids: a_collection_containing_exactly("liked-card-1")
          ).and_return(intent_engine)

          post deck_suggestion_feedbacks_path(deck),
            params: { scryfall_id: scryfall_id, card_name: card_name, feedback: "down" },
            headers: turbo_headers
        end
      end

      context "when no replacement card is available" do
        it "responds with only a remove stream" do
          post deck_suggestion_feedbacks_path(deck),
            params: { scryfall_id: scryfall_id, card_name: card_name, feedback: "down" },
            headers: turbo_headers

          expect(response.body).to include("remove")
          expect(response.body).not_to include("append")
        end
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
        allow(merge_suggestions).to receive(:call).and_return([ new_card_suggestion ])

        post deck_suggestion_feedbacks_path(deck),
          params: { scryfall_id: scryfall_id, card_name: card_name, feedback: "up" },
          headers: turbo_headers

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("suggestions-grid")
      end

      it "calls SuggestionEngine and IntentEngine with liked_ids including the newly thumbed card" do
        create(:suggestion_feedback, deck: deck, scryfall_id: "existing-up", feedback: "up")

        expect(SuggestionEngine).to receive(:new).with(
          deck, liked_ids: a_collection_containing_exactly("existing-up", scryfall_id)
        ).and_return(suggestion_engine)
        expect(IntentEngine).to receive(:new).with(
          deck, liked_ids: a_collection_containing_exactly("existing-up", scryfall_id)
        ).and_return(intent_engine)

        post deck_suggestion_feedbacks_path(deck),
          params: { scryfall_id: scryfall_id, card_name: card_name, feedback: "up" },
          headers: turbo_headers
      end

      it "does not append cards that already have feedback" do
        thumbed_down_card = {
          card: {
            "id"             => "already-feedbacked",
            "name"           => "Feedbacked Card",
            "type_line"      => "Artifact",
            "cmc"            => 2,
            "color_identity" => [],
            "keywords"       => [],
            "oracle_text"    => "",
            "image_uris"     => {}
          },
          score: 5,
          reasons: []
        }
        create(:suggestion_feedback, deck: deck, scryfall_id: "already-feedbacked",
               card_name: "Feedbacked Card", feedback: "down")
        allow(merge_suggestions).to receive(:call).and_return([ thumbed_down_card ])

        post deck_suggestion_feedbacks_path(deck),
          params: { scryfall_id: scryfall_id, card_name: card_name, feedback: "up" },
          headers: turbo_headers

        expect(response.body).not_to include("already-feedbacked")
      end

      it "does not append the commander card" do
        commander_as_suggestion = {
          card: {
            "id"             => commander.scryfall_id,
            "name"           => commander.name,
            "type_line"      => "Legendary Creature",
            "cmc"            => 4,
            "color_identity" => [ "U" ],
            "keywords"       => [],
            "oracle_text"    => "",
            "image_uris"     => {}
          },
          score: 10,
          reasons: []
        }
        allow(merge_suggestions).to receive(:call).and_return([ commander_as_suggestion ])

        post deck_suggestion_feedbacks_path(deck),
          params: { scryfall_id: scryfall_id, card_name: card_name, feedback: "up" },
          headers: turbo_headers

        expect(response.body).not_to include("suggestion-#{commander.scryfall_id}")
      end

      it "appends at most 3 new cards to suggestions-grid" do
        many_cards = (1..6).map do |i|
          { card: { "id"             => "new-#{i}",
                    "name"           => "Card #{i}",
                    "type_line"      => "Artifact",
                    "cmc"            => 1,
                    "color_identity" => [],
                    "keywords"       => [],
                    "oracle_text"    => "",
                    "image_uris"     => {} },
            score: 7 - i, reasons: [], pool: "Ramp" }
        end
        allow(merge_suggestions).to receive(:call).and_return(many_cards)

        post deck_suggestion_feedbacks_path(deck),
          params: { scryfall_id: scryfall_id, card_name: card_name, feedback: "up" },
          headers: turbo_headers

        append_count = response.body.scan('<turbo-stream action="append"').count
        expect(append_count).to be <= 3
      end

      it "does not append the just-thumbed-up card itself to new suggestions" do
        same_card = {
          card: {
            "id"             => scryfall_id,
            "name"           => card_name,
            "type_line"      => "Artifact",
            "cmc"            => 1,
            "color_identity" => [],
            "keywords"       => [],
            "oracle_text"    => "",
            "image_uris"     => {}
          },
          score: 10,
          reasons: []
        }
        allow(merge_suggestions).to receive(:call).and_return([ same_card, new_card_suggestion ])

        post deck_suggestion_feedbacks_path(deck),
          params: { scryfall_id: scryfall_id, card_name: card_name, feedback: "up" },
          headers: turbo_headers

        expect(response.body).not_to include("suggestion-#{scryfall_id}")
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
