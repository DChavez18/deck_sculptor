require "rails_helper"

RSpec.describe "Cards", type: :request do
  let(:scryfall_service) { instance_double(ScryfallService) }
  let(:card_results) do
    [
      {
        "id"         => "abc-123",
        "name"       => "Lightning Bolt",
        "mana_cost"  => "{R}",
        "type_line"  => "Instant",
        "image_uris" => { "small" => "https://cards.scryfall.io/small/front/test.jpg" }
      }
    ]
  end

  before do
    allow(ScryfallService).to receive(:new).and_return(scryfall_service)
  end

  describe "GET /cards/search" do
    context "when query has 2+ characters" do
      before do
        allow(scryfall_service).to receive(:search_cards).with("Lightning").and_return(card_results)
        get search_cards_path, params: { q: "Lightning" }
      end

      it { expect(response).to have_http_status(:ok) }

      it "renders card names" do
        expect(response.body).to include("Lightning Bolt")
      end

      it "renders mana cost" do
        expect(response.body).to include("{R}")
      end

      it "renders the card image" do
        expect(response.body).to include("https://cards.scryfall.io/small/front/test.jpg")
      end
    end

    context "when query is blank" do
      before do
        allow(scryfall_service).to receive(:search_cards)
        get search_cards_path, params: { q: "" }
      end

      it { expect(response).to have_http_status(:ok) }

      it "does not call ScryfallService" do
        expect(scryfall_service).not_to have_received(:search_cards)
      end
    end

    context "when query is only 1 character" do
      before do
        allow(scryfall_service).to receive(:search_cards)
        get search_cards_path, params: { q: "L" }
      end

      it { expect(response).to have_http_status(:ok) }

      it "does not call ScryfallService" do
        expect(scryfall_service).not_to have_received(:search_cards)
      end
    end

    context "when no cards match" do
      before do
        allow(scryfall_service).to receive(:search_cards).with("xyzzy").and_return([])
        get search_cards_path, params: { q: "xyzzy" }
      end

      it { expect(response).to have_http_status(:ok) }

      it "renders no cards found message" do
        expect(response.body).to include("No cards found")
      end
    end

    context "with a double-faced card (no top-level image_uris)" do
      let(:dfc_results) do
        [
          {
            "id"         => "dfc-456",
            "name"       => "Delver of Secrets",
            "mana_cost"  => "{U}",
            "type_line"  => "Creature — Human Wizard",
            "card_faces" => [
              { "image_uris" => { "small" => "https://cards.scryfall.io/small/front/dfc.jpg" } }
            ]
          }
        ]
      end

      before do
        allow(scryfall_service).to receive(:search_cards).with("Delver").and_return(dfc_results)
        get search_cards_path, params: { q: "Delver" }
      end

      it { expect(response).to have_http_status(:ok) }

      it "renders the front face image" do
        expect(response.body).to include("https://cards.scryfall.io/small/front/dfc.jpg")
      end
    end
  end
end
