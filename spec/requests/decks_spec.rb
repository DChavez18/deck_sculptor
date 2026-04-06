require "rails_helper"

RSpec.describe "Decks", type: :request do
  let!(:commander) { create(:commander) }
  let!(:deck) { create(:deck, commander: commander) }

  describe "GET /decks" do
    before { get decks_path }

    it { expect(response).to have_http_status(:ok) }
  end

  describe "GET /decks/new" do
    before { get new_deck_path }

    it { expect(response).to have_http_status(:ok) }
  end

  describe "POST /decks" do
    context "with valid params" do
      let(:params) do
        {
          deck: {
            name: "My Deck",
            commander_id: commander.id,
            archetype: "control",
            bracket_level: 3
          }
        }
      end

      it "creates a deck and redirects to intent page" do
        expect { post decks_path, params: params }.to change(Deck, :count).by(1)
        expect(response).to redirect_to(intent_deck_path(Deck.last))
      end
    end

    context "with invalid params" do
      let(:params) { { deck: { name: "" } } }

      it "does not create a deck and re-renders new" do
        expect { post decks_path, params: params }.not_to change(Deck, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /decks/:id" do
    before { get deck_path(deck) }

    it { expect(response).to have_http_status(:ok) }
  end

  describe "GET /decks/:id/edit" do
    before { get edit_deck_path(deck) }

    it { expect(response).to have_http_status(:ok) }
  end

  describe "PATCH /decks/:id" do
    context "with valid params" do
      it "updates the deck and redirects to show" do
        patch deck_path(deck), params: { deck: { name: "Updated Name" } }
        expect(response).to redirect_to(deck_path(deck))
        expect(deck.reload.name).to eq("Updated Name")
      end
    end

    context "with invalid params" do
      it "re-renders edit with unprocessable entity" do
        patch deck_path(deck), params: { deck: { name: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /decks/:id" do
    it "destroys the deck and redirects to index" do
      expect { delete deck_path(deck) }.to change(Deck, :count).by(-1)
      expect(response).to redirect_to(decks_path)
    end
  end

  describe "GET /decks/:id/suggestions" do
    let(:suggestion_engine) { instance_double(SuggestionEngine, suggestions: []) }
    let(:intent_engine)     { instance_double(IntentEngine, suggestions: []) }
    let(:edhrec_service)    { instance_double(EdhrecService, top_cards: []) }

    before do
      allow(SuggestionEngine).to receive(:new).and_return(suggestion_engine)
      allow(IntentEngine).to receive(:new).and_return(intent_engine)
      allow(EdhrecService).to receive(:new).and_return(edhrec_service)
      get suggestions_deck_path(deck)
    end

    it { expect(response).to have_http_status(:ok) }

    it "calls both SuggestionEngine and IntentEngine" do
      expect(SuggestionEngine).to have_received(:new).with(deck)
      expect(IntentEngine).to have_received(:new).with(deck)
    end

    context "when a card has existing feedback" do
      let(:feedbacked_card) do
        { card: { "id"             => "feedbacked-1",
                  "name"           => "Feedbacked Card",
                  "type_line"      => "Artifact",
                  "cmc"            => 1,
                  "color_identity" => [],
                  "keywords"       => [],
                  "oracle_text"    => "",
                  "image_uris"     => {} },
          score: 5, reasons: [], pool: "Ramp" }
      end
      let(:merge_instance) { instance_double(MergeSuggestions) }

      before do
        allow(MergeSuggestions).to receive(:new).and_return(merge_instance)
        allow(merge_instance).to receive(:call).and_return([ feedbacked_card ])
      end

      it "excludes cards in deck.blacklisted_card_ids from the rendered page" do
        create(:suggestion_feedback, deck: deck, scryfall_id: "feedbacked-1",
               card_name: "Feedbacked Card", feedback: "down")
        deck.blacklist_card("feedbacked-1")
        get suggestions_deck_path(deck)
        expect(response.body).not_to include("feedbacked-1")
      end

      it "does not exclude cards with 'up' feedback from the rendered page" do
        create(:suggestion_feedback, deck: deck, scryfall_id: "feedbacked-1",
               card_name: "Feedbacked Card", feedback: "up")
        get suggestions_deck_path(deck)
        expect(response.body).to include("feedbacked-1")
      end
    end

    context "when a card uses scryfall_id key instead of id" do
      let(:feedbacked_card_alt_key) do
        { card: { "scryfall_id"   => "feedbacked-alt",
                  "name"           => "Alt Key Card",
                  "type_line"      => "Artifact",
                  "cmc"            => 1,
                  "color_identity" => [],
                  "keywords"       => [],
                  "oracle_text"    => "",
                  "image_uris"     => {} },
          score: 5, reasons: [], pool: "Ramp" }
      end
      let(:merge_instance) { instance_double(MergeSuggestions) }

      before do
        create(:suggestion_feedback, deck: deck, scryfall_id: "feedbacked-alt",
               card_name: "Alt Key Card", feedback: "down")
        allow(MergeSuggestions).to receive(:new).and_return(merge_instance)
        allow(merge_instance).to receive(:call).and_return([ feedbacked_card_alt_key ])
        get suggestions_deck_path(deck)
      end

      it "excludes the card via the scryfall_id fallback" do
        expect(response.body).not_to include("feedbacked-alt")
      end
    end
  end

  describe "GET /decks/:id/more_suggestions" do
    let(:suggestion_engine) { instance_double(SuggestionEngine, suggestions: []) }
    let(:intent_engine)     { instance_double(IntentEngine, suggestions: []) }
    let(:turbo_headers)     { { "Accept" => "text/vnd.turbo-stream.html" } }

    def make_suggestion(id, score)
      { card: { "id"             => id,
                "name"           => "Card #{id}",
                "type_line"      => "Artifact",
                "cmc"            => 1,
                "color_identity" => [],
                "keywords"       => [],
                "oracle_text"    => "",
                "image_uris"     => {} },
        score:   score,
        reasons: [],
        pool:    "Ramp" }
    end

    before do
      allow(SuggestionEngine).to receive(:new).and_return(suggestion_engine)
      allow(IntentEngine).to receive(:new).and_return(intent_engine)
    end

    context "when page 2 has cards and no further pages remain" do
      let(:all_suggestions) do
        (1..31).map { |i| make_suggestion("pg-card-#{i}", 32 - i) }
      end
      let(:merge_instance) { instance_double(MergeSuggestions, call: all_suggestions) }

      before do
        allow(MergeSuggestions).to receive(:new).and_return(merge_instance)
      end

      it "returns turbo stream appending the page-2 card to suggestions-grid" do
        get more_suggestions_deck_path(deck, page: 2), headers: turbo_headers
        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("pg-card-31")
        expect(response.body).to include("suggestions-grid")
      end

      it "removes the load-more button when no further pages remain" do
        get more_suggestions_deck_path(deck, page: 2), headers: turbo_headers
        expect(response.body).to include("remove")
        expect(response.body).to include("load-more-btn")
      end
    end

    context "when there are more pages after the requested one" do
      let(:all_suggestions) do
        (1..61).map { |i| make_suggestion("multi-#{i}", 62 - i) }
      end
      let(:merge_instance) { instance_double(MergeSuggestions, call: all_suggestions) }

      before do
        allow(MergeSuggestions).to receive(:new).and_return(merge_instance)
      end

      it "updates the load-more button with the next page number" do
        get more_suggestions_deck_path(deck, page: 1), headers: turbo_headers
        expect(response.body).to include("load-more-btn")
        expect(response.body).to include("page=2")
      end
    end

    context "when no suggestions remain on the requested page" do
      let(:merge_instance) { instance_double(MergeSuggestions, call: []) }

      before do
        allow(MergeSuggestions).to receive(:new).and_return(merge_instance)
      end

      it "removes the load-more button" do
        get more_suggestions_deck_path(deck, page: 2), headers: turbo_headers
        expect(response.body).to include("remove")
        expect(response.body).to include("load-more-btn")
      end
    end
  end


  describe "GET /decks/:id/analysis" do
    let(:combo_service) { instance_double(ComboFinderService, find_combos: [], near_miss_combos: []) }

    before do
      allow(ComboFinderService).to receive(:new).and_return(combo_service)
      allow(UpgradeFinder).to receive(:new).and_return(instance_double(UpgradeFinder, upgrades: []))
      get analysis_deck_path(deck)
    end

    it { expect(response).to have_http_status(:ok) }
  end

  describe "GET /decks/:id/intent" do
    before { get intent_deck_path(deck) }

    it { expect(response).to have_http_status(:ok) }
  end

  describe "POST /decks/:id/save_intent" do
    context "with valid params" do
      let(:params) do
        {
          deck: {
            win_condition: "Infinite combo",
            budget: "optimized",
            archetype: "combo",
            themes: "tokens, aristocrats"
          }
        }
      end

      it "saves intent and redirects to deck show" do
        post save_intent_deck_path(deck), params: params
        expect(response).to redirect_to(deck_path(deck))
        deck.reload
        expect(deck.win_condition).to eq("Infinite combo")
        expect(deck.budget).to eq("optimized")
        expect(deck.themes).to eq("tokens, aristocrats")
        expect(deck.intent_completed).to be true
      end
    end
  end
end
