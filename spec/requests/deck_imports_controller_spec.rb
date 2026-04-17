require "rails_helper"

RSpec.describe "DeckImports", type: :request do
  let!(:commander) { create(:commander) }
  let!(:deck)      { create(:deck, commander: commander) }

  let(:scryfall_service) { instance_double(ScryfallService) }
  let(:card_data) do
    {
      "id"             => "scryfall-sol-ring",
      "name"           => "Sol Ring",
      "type_line"      => "Artifact",
      "cmc"            => 1.0,
      "color_identity" => [],
      "image_uris"     => { "normal" => "https://cards.scryfall.io/normal/front/sol.jpg" }
    }
  end

  let(:turbo_headers) { { "Accept" => "text/vnd.turbo-stream.html" } }

  before do
    allow(ScryfallService).to receive(:new).and_return(scryfall_service)
    allow(CardCache).to receive(:fetch_by_name).and_return(nil)
  end

  describe "POST /decks/:deck_id/deck_imports" do
    context "with a valid decklist" do
      before do
        allow(scryfall_service).to receive(:find_card_by_name).with("Sol Ring").and_return(card_data)
      end

      it "creates deck cards" do
        expect {
          post deck_deck_imports_path(deck),
               params: { decklist: "1 Sol Ring" },
               headers: turbo_headers
        }.to change(DeckCard, :count).by(1)
      end

      it "responds with Turbo Stream" do
        post deck_deck_imports_path(deck),
             params: { decklist: "1 Sol Ring" },
             headers: turbo_headers

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("deck_card_list")
        expect(response.body).to include("import-result")
        expect(response.body).to include("Imported 1 cards")
      end
    end

    context "when a card is not found" do
      before do
        allow(scryfall_service).to receive(:find_card_by_name).with("Bogus Card").and_return(nil)
      end

      it "does not create deck cards" do
        expect {
          post deck_deck_imports_path(deck),
               params: { decklist: "1 Bogus Card" },
               headers: turbo_headers
        }.not_to change(DeckCard, :count)
      end

      it "reports not found in the result stream" do
        post deck_deck_imports_path(deck),
             params: { decklist: "1 Bogus Card" },
             headers: turbo_headers

        expect(response.body).to include("not found")
        expect(response.body).to include("Bogus Card")
      end
    end

    context "with an empty decklist" do
      it "does not create deck cards" do
        expect {
          post deck_deck_imports_path(deck),
               params: { decklist: "" },
               headers: turbo_headers
        }.not_to change(DeckCard, :count)
      end

      it "returns an error Turbo Stream" do
        post deck_deck_imports_path(deck),
             params: { decklist: "" },
             headers: turbo_headers

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("import-result")
        expect(response.body).to include("Could not parse")
      end
    end

    context "when the decklist contains the commander name" do
      it "skips a card that matches the deck's commander name" do
        expect {
          post deck_deck_imports_path(deck),
               params: { decklist: "1 #{commander.name}" },
               headers: turbo_headers
        }.not_to change(DeckCard, :count)

        expect(response).to be_successful
      end
    end

    context "when importing a card with quantity > 1" do
      before do
        allow(scryfall_service).to receive(:find_card_by_name).with("Island").and_return(
          card_data.merge("id" => "scryfall-island", "name" => "Island", "type_line" => "Basic Land")
        )
      end

      it "creates the deck card with the correct quantity" do
        post deck_deck_imports_path(deck),
             params: { decklist: "26 Island" },
             headers: turbo_headers

        expect(DeckCard.last.quantity).to eq(26)
      end
    end

    context "when a card is already in the deck (duplicate)" do
      let!(:existing_card) do
        create(:deck_card, deck: deck, scryfall_id: "scryfall-sol-ring", card_name: "Sol Ring",
               category: "artifact", type_line: "Artifact", cmc: 1.0, color_identity: "",
               quantity: 1)
      end

      before do
        allow(scryfall_service).to receive(:find_card_by_name).with("Sol Ring").and_return(card_data)
      end

      it "does not create a new deck card" do
        expect {
          post deck_deck_imports_path(deck),
               params: { decklist: "3 Sol Ring" },
               headers: turbo_headers
        }.not_to change(DeckCard, :count)
      end

      it "updates the quantity of the existing deck card" do
        post deck_deck_imports_path(deck),
             params: { decklist: "3 Sol Ring" },
             headers: turbo_headers

        expect(existing_card.reload.quantity).to eq(3)
      end

      it "counts the update as skipped in the summary" do
        post deck_deck_imports_path(deck),
             params: { decklist: "3 Sol Ring" },
             headers: turbo_headers

        expect(response.body).to include("skipped")
      end
    end
  end
end
