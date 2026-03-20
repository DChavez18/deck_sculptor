require "rails_helper"

RSpec.describe "DeckCards", type: :request do
  let!(:commander) { create(:commander) }
  let!(:deck) { create(:deck, commander: commander) }
  let(:scryfall_service) { instance_double(ScryfallService) }
  let(:card_data) do
    {
      "id"           => "scryfall-123",
      "name"         => "Counterspell",
      "type_line"    => "Instant",
      "mana_cost"    => "{U}{U}",
      "cmc"          => 2.0,
      "color_identity" => [ "U" ],
      "oracle_text"  => "Counter target spell.",
      "image_uris"   => { "normal" => "https://cards.scryfall.io/normal/front/test.jpg" }
    }
  end

  before do
    allow(ScryfallService).to receive(:new).and_return(scryfall_service)
  end

  describe "POST /decks/:deck_id/deck_cards" do
    context "when card is found on Scryfall" do
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
    end

    context "when scryfall_id is blank" do
      let(:params) { { deck_card: { scryfall_id: "", card_name: "Counterspell", quantity: 1 } } }

      it "does not create a deck card" do
        expect { post deck_deck_cards_path(deck), params: params }.not_to change(DeckCard, :count)
        expect(response).to have_http_status(:unprocessable_entity)
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
