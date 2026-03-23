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
        expect(DeckCard.last.category).to eq("instant")
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
        expect(DeckCard.last.category).to eq("instant")
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
  end

  describe "DELETE /decks/:deck_id/deck_cards/:id" do
    let!(:deck_card) { create(:deck_card, deck: deck) }

    it "destroys the deck card and redirects to deck" do
      expect { delete deck_deck_card_path(deck, deck_card) }.to change(DeckCard, :count).by(-1)
      expect(response).to redirect_to(deck_path(deck))
    end
  end
end
