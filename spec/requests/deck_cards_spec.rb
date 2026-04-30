require "rails_helper"

RSpec.describe "DeckCards", type: :request do
  let!(:commander) { create(:commander) }
  let!(:deck) { create(:deck, commander: commander) }
  let(:scryfall_service) { instance_double(ScryfallService) }
  let(:card_data) do
    {
      "id"             => "scryfall-123",
      "name"           => "Counterspell",
      "type_line"      => "Instant",
      "mana_cost"      => "{U}{U}",
      "cmc"            => 2.0,
      "color_identity" => [ "U" ],
      "oracle_text"    => "Counter target spell.",
      "image_uris"     => { "normal" => "https://cards.scryfall.io/normal/front/test.jpg" }
    }
  end

  before do
    allow(ScryfallService).to receive(:new).and_return(scryfall_service)
  end

  describe "POST /decks/:deck_id/deck_cards" do
    context "when scryfall_id is provided and card is found" do
      before do
        allow(scryfall_service).to receive(:find_card_by_id).with("scryfall-123").and_return(card_data)
      end

      let(:params) { { deck_card: { scryfall_id: "scryfall-123", card_name: "Counterspell", quantity: 1 } } }

      it "creates a deck card and redirects to deck" do
        expect { post deck_deck_cards_path(deck), params: params }.to change(DeckCard, :count).by(1)
        expect(response).to redirect_to(deck_path(deck))
      end

      it "auto-categorizes the card" do
        post deck_deck_cards_path(deck), params: params
        expect(DeckCard.last.category).to eq("removal")
      end

      it "uses Scryfall card name, not the submitted name" do
        post deck_deck_cards_path(deck), params: params
        expect(DeckCard.last.card_name).to eq("Counterspell")
      end
    end

    context "when only card_name is provided (no scryfall_id)" do
      before do
        allow(scryfall_service).to receive(:find_card_by_name).with("Counterspell").and_return(card_data)
      end

      let(:params) { { deck_card: { scryfall_id: "", card_name: "Counterspell", quantity: 1 } } }

      it "creates a deck card and redirects to deck" do
        expect { post deck_deck_cards_path(deck), params: params }.to change(DeckCard, :count).by(1)
        expect(response).to redirect_to(deck_path(deck))
      end

      it "auto-categorizes the card" do
        post deck_deck_cards_path(deck), params: params
        expect(DeckCard.last.category).to eq("removal")
      end
    end

    context "when card is not found by name" do
      before do
        allow(scryfall_service).to receive(:find_card_by_name).with("Bogus Card").and_return(nil)
      end

      let(:params) { { deck_card: { scryfall_id: "", card_name: "Bogus Card", quantity: 1 } } }

      it "does not create a deck card" do
        expect { post deck_deck_cards_path(deck), params: params }.not_to change(DeckCard, :count)
      end

      it "redirects to deck with an alert" do
        post deck_deck_cards_path(deck), params: params
        expect(response).to redirect_to(deck_path(deck))
        follow_redirect!
        expect(response.body).to include("Card not found")
      end
    end

    context "when both scryfall_id and card_name are blank" do
      before do
        # no lookup methods should be called
      end

      let(:params) { { deck_card: { scryfall_id: "", card_name: "", quantity: 1 } } }

      it "does not create a deck card and redirects with alert" do
        expect { post deck_deck_cards_path(deck), params: params }.not_to change(DeckCard, :count)
        expect(response).to redirect_to(deck_path(deck))
      end
    end

    context "when adding from the deck show page via Turbo Stream" do
      before do
        allow(scryfall_service).to receive(:find_card_by_id).with("scryfall-123").and_return(card_data)
      end

      let(:params) { { deck_card: { scryfall_id: "scryfall-123", card_name: "Counterspell", quantity: 1 } } }

      it "returns a Turbo Stream that updates the deck card list" do
        post deck_deck_cards_path(deck),
          params: params,
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include('action="update"')
        expect(response.body).to include("deck_card_list")
      end

      it "also includes the remove action for the suggestions page (regression guard)" do
        post deck_deck_cards_path(deck),
          params: params,
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.body).to include('action="remove"')
        expect(response.body).to include("suggestion-scryfall-123")
      end

      it "creates the deck card record" do
        expect {
          post deck_deck_cards_path(deck),
            params: params,
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
        }.to change(DeckCard, :count).by(1)
      end
    end

    context "when adding from the suggestions page via Turbo Stream" do
      before do
        allow(scryfall_service).to receive(:find_card_by_id).with("scryfall-123").and_return(card_data)
      end

      let(:params) { { deck_card: { scryfall_id: "scryfall-123", card_name: "Counterspell", quantity: 1, return_to: "suggestions" } } }

      it "responds with a Turbo Stream that removes the card from the suggestions grid" do
        post deck_deck_cards_path(deck),
          params: params,
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("remove")
        expect(response.body).to include("suggestion-scryfall-123")
      end

      it "still creates the deck card" do
        expect {
          post deck_deck_cards_path(deck),
            params: params,
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
        }.to change(DeckCard, :count).by(1)
      end
    end

    context "when adding from the suggestions page via HTML" do
      before do
        allow(scryfall_service).to receive(:find_card_by_id).with("scryfall-123").and_return(card_data)
      end

      let(:params) { { deck_card: { scryfall_id: "scryfall-123", card_name: "Counterspell", quantity: 1, return_to: "suggestions" } } }

      it "redirects back to the suggestions page" do
        post deck_deck_cards_path(deck), params: params
        expect(response).to redirect_to(suggestions_deck_path(deck))
      end
    end

    context "when the same card is added twice (duplicate)" do
      before do
        allow(scryfall_service).to receive(:find_card_by_id).with("scryfall-123").and_return(card_data)
        create(:deck_card, deck: deck, scryfall_id: "scryfall-123", card_name: "Counterspell",
               category: "instant", type_line: "Instant", cmc: 2.0, color_identity: "U")
      end

      let(:params) { { deck_card: { scryfall_id: "scryfall-123", card_name: "Counterspell", quantity: 1 } } }

      it "does not raise a 500" do
        post deck_deck_cards_path(deck), params: params
        expect(response).not_to have_http_status(:internal_server_error)
      end

      it "redirects to the deck with an already-in-deck notice" do
        post deck_deck_cards_path(deck), params: params
        expect(response).to redirect_to(deck_path(deck))
        follow_redirect!
        expect(response.body).to include("already in your deck")
      end

      it "responds with a turbo stream remove via Turbo, no 500" do
        post deck_deck_cards_path(deck),
          params: params,
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).not_to have_http_status(:internal_server_error)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("remove")
        expect(response.body).to include("suggestion-scryfall-123")
      end
    end
  end

  describe "POST /decks/:deck_id/deck_cards — MDFC card" do
    let(:mdfc_data) do
      {
        "id"             => "mdfc-001",
        "name"           => "Sink into Stupor // Soporific Springs",
        "type_line"      => "Instant // Land",
        "mana_cost"      => "{2}{U}",
        "cmc"            => 3.0,
        "color_identity" => [ "U" ],
        "oracle_text"    => nil,
        "image_uris"     => { "normal" => "https://cards.scryfall.io/normal/front/test.jpg" },
        "card_faces"     => [
          { "type_line" => "Instant", "oracle_text" => "Return target nonland permanent to its owner's hand.", "keywords" => [] },
          { "type_line" => "Land",    "oracle_text" => "Soporific Springs enters the battlefield tapped.", "keywords" => [] }
        ]
      }
    end

    before do
      allow(scryfall_service).to receive(:find_card_by_id).with("mdfc-001").and_return(mdfc_data)
    end

    let(:params) { { deck_card: { scryfall_id: "mdfc-001", card_name: "Sink into Stupor // Soporific Springs", quantity: 1 } } }

    it "sets primary category from front face" do
      post deck_deck_cards_path(deck), params: params
      expect(DeckCard.last.category).to eq("removal")
    end

    it "stores the back face category in secondary_categories" do
      post deck_deck_cards_path(deck), params: params
      expect(DeckCard.last.secondary_categories).to eq("land")
    end
  end

  describe "PATCH /decks/:deck_id/deck_cards/:id" do
    context "increasing quantity on a basic land" do
      let!(:deck_card) { create(:deck_card, :land, deck: deck, card_name: "Forest", quantity: 3) }

      it "increases the quantity and redirects to deck" do
        patch deck_deck_card_path(deck, deck_card), params: { deck_card: { quantity: 4 } }
        expect(deck_card.reload.quantity).to eq(4)
        expect(response).to redirect_to(deck_path(deck))
      end

      it "responds with turbo stream when requested" do
        patch deck_deck_card_path(deck, deck_card),
          params: { deck_card: { quantity: 4 } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(deck_card.reload.quantity).to eq(4)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("deck_stats")
        expect(response.body).to include("deck_card_list")
      end
    end

    context "decreasing quantity on a basic land" do
      let!(:deck_card) { create(:deck_card, :land, deck: deck, card_name: "Forest", quantity: 3) }

      it "decreases the quantity and redirects to deck" do
        patch deck_deck_card_path(deck, deck_card), params: { deck_card: { quantity: 2 } }
        expect(deck_card.reload.quantity).to eq(2)
        expect(response).to redirect_to(deck_path(deck))
      end

      it "responds with turbo stream when requested" do
        patch deck_deck_card_path(deck, deck_card),
          params: { deck_card: { quantity: 2 } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(deck_card.reload.quantity).to eq(2)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("deck_stats")
        expect(response.body).to include("deck_card_list")
      end
    end

    context "quantity reaches 0" do
      let!(:deck_card) { create(:deck_card, deck: deck, quantity: 1) }

      it "destroys the deck card and redirects to deck" do
        expect { patch deck_deck_card_path(deck, deck_card), params: { deck_card: { quantity: 0 } } }
          .to change(DeckCard, :count).by(-1)
        expect(response).to redirect_to(deck_path(deck))
      end
    end

    context "enforcing 1-copy limit for non-basic cards" do
      let!(:deck_card) { create(:deck_card, deck: deck, card_name: "Counterspell", quantity: 1) }

      it "rejects quantity > 1 and redirects with alert" do
        patch deck_deck_card_path(deck, deck_card), params: { deck_card: { quantity: 2 } }
        expect(deck_card.reload.quantity).to eq(1)
        expect(response).to redirect_to(deck_path(deck))
        follow_redirect!
        expect(response.body).to include("Non-basic cards are limited to 1 copy")
      end
    end
  end

  describe "DELETE /decks/:deck_id/deck_cards/:id" do
    let!(:deck_card) { create(:deck_card, deck: deck) }

    it "destroys the deck card and redirects to deck" do
      expect { delete deck_deck_card_path(deck, deck_card) }.to change(DeckCard, :count).by(-1)
      expect(response).to redirect_to(deck_path(deck))
    end
  end
end
