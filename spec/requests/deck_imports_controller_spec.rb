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
      "oracle_text"    => "{T}: Add {C}{C}.",
      "cmc"            => 1.0,
      "color_identity" => [],
      "image_uris"     => { "normal" => "https://cards.scryfall.io/normal/front/sol.jpg" }
    }
  end

  let(:turbo_headers) { { "Accept" => "text/vnd.turbo-stream.html" } }

  before do
    allow(ScryfallService).to receive(:new).and_return(scryfall_service)
    allow(CardCache).to receive(:fetch_by_names).and_return({})
  end

  describe "POST /decks/:deck_id/deck_imports" do
    context "with a valid decklist" do
      before do
        allow(scryfall_service).to receive(:find_cards_by_names).and_return("Sol Ring" => card_data)
      end

      it "creates deck cards" do
        expect {
          post deck_deck_imports_path(deck),
               params: { decklist: "1 Sol Ring" },
               headers: turbo_headers
        }.to change(DeckCard, :count).by(1)
      end

      it "persists oracle_text and raw_data for accurate ratio analysis" do
        post deck_deck_imports_path(deck),
             params: { decklist: "1 Sol Ring" },
             headers: turbo_headers

        deck_card = DeckCard.last
        expect(deck_card.oracle_text).to eq(card_data["oracle_text"])
        expect(deck_card.raw_data).to eq(card_data)
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
        allow(scryfall_service).to receive(:find_cards_by_names).and_return({})
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
      before do
        allow(scryfall_service).to receive(:find_cards_by_names).and_return({})
      end

      it "skips a card that matches the deck's commander name" do
        expect {
          post deck_deck_imports_path(deck),
               params: { decklist: "1 #{commander.name}" },
               headers: turbo_headers
        }.not_to change(DeckCard, :count)

        expect(response).to be_successful
      end
    end

    context "deck card list groups by card type (not functional role)" do
      let(:bloom_tender_data) do
        {
          "id"             => "bloom-tender-import",
          "name"           => "Bloom Tender",
          "type_line"      => "Legendary Creature — Elf Druid",
          "cmc"            => 2.0,
          "color_identity" => [ "G" ],
          "oracle_text"    => "{T}: For each color among permanents you control, add one mana of that color.",
          "image_uris"     => { "normal" => "https://cards.scryfall.io/normal/front/bloom.jpg" }
        }
      end

      before do
        allow(scryfall_service).to receive(:find_cards_by_names).and_return("Bloom Tender" => bloom_tender_data)
      end

      it "renders Bloom Tender under the Creature section header, not Ramp" do
        post deck_deck_imports_path(deck),
             params: { decklist: "1 Bloom Tender" },
             headers: turbo_headers

        expect(response.body).to match(%r{<h3[^>]*>\s*Creature\s*</h3>}i)
        expect(response.body).not_to match(%r{<h3[^>]*>\s*Ramp\s*</h3>}i)
      end
    end

    context "when importing a card with quantity > 1" do
      before do
        allow(scryfall_service).to receive(:find_cards_by_names).and_return(
          "Island" => card_data.merge("id" => "scryfall-island", "name" => "Island", "type_line" => "Basic Land")
        )
      end

      it "creates the deck card with the correct quantity" do
        post deck_deck_imports_path(deck),
             params: { decklist: "26 Island" },
             headers: turbo_headers

        expect(DeckCard.last.quantity).to eq(26)
      end
    end

    context "when a non-land card is already in the deck (duplicate)" do
      let!(:existing_card) do
        create(:deck_card, deck: deck, scryfall_id: "scryfall-sol-ring", card_name: "Sol Ring",
               category: "artifact", type_line: "Artifact", cmc: 1.0, color_identity: "",
               quantity: 1)
      end

      before do
        allow(scryfall_service).to receive(:find_cards_by_names).and_return("Sol Ring" => card_data)
      end

      it "does not create a new deck card" do
        expect {
          post deck_deck_imports_path(deck),
               params: { decklist: "3 Sol Ring" },
               headers: turbo_headers
        }.not_to change(DeckCard, :count)
      end

      it "leaves the existing quantity unchanged" do
        post deck_deck_imports_path(deck),
             params: { decklist: "3 Sol Ring" },
             headers: turbo_headers

        expect(existing_card.reload.quantity).to eq(1)
      end

      it "counts the duplicate as skipped in the summary" do
        post deck_deck_imports_path(deck),
             params: { decklist: "3 Sol Ring" },
             headers: turbo_headers

        expect(response.body).to include("skipped")
      end
    end

    context "when a basic land is already in the deck (duplicate)" do
      let!(:existing_forest) do
        create(:deck_card, deck: deck, scryfall_id: "scryfall-forest", card_name: "Forest",
               category: "land", type_line: "Basic Land — Forest", cmc: 0.0, color_identity: "",
               quantity: 10)
      end

      before do
        allow(scryfall_service).to receive(:find_cards_by_names).and_return(
          "Forest" => card_data.merge("id" => "scryfall-forest", "name" => "Forest", "type_line" => "Basic Land — Forest")
        )
      end

      it "sums the quantity onto the existing deck card" do
        post deck_deck_imports_path(deck),
             params: { decklist: "5 Forest" },
             headers: turbo_headers

        expect(existing_forest.reload.quantity).to eq(15)
      end
    end

    context "when a snow-covered basic land is already in the deck (duplicate)" do
      let!(:existing_snow_forest) do
        create(:deck_card, deck: deck, scryfall_id: "scryfall-snow-forest", card_name: "Snow-Covered Forest",
               category: "land", type_line: "Basic Snow Land — Forest", cmc: 0.0, color_identity: "",
               quantity: 3)
      end

      before do
        allow(scryfall_service).to receive(:find_cards_by_names).and_return(
          "Snow-Covered Forest" => card_data.merge("id" => "scryfall-snow-forest", "name" => "Snow-Covered Forest",
                                                    "type_line" => "Basic Snow Land — Forest")
        )
      end

      it "sums the quantity onto the existing deck card" do
        post deck_deck_imports_path(deck),
             params: { decklist: "2 Snow-Covered Forest" },
             headers: turbo_headers

        expect(existing_snow_forest.reload.quantity).to eq(5)
      end
    end

    context "when a card is already in the CardCache" do
      before do
        allow(CardCache).to receive(:fetch_by_names).with([ "Sol Ring" ]).and_return("Sol Ring" => card_data)
        allow(scryfall_service).to receive(:find_cards_by_names).and_return({})
      end

      it "does not hit Scryfall for the cached card" do
        post deck_deck_imports_path(deck),
             params: { decklist: "1 Sol Ring" },
             headers: turbo_headers

        expect(scryfall_service).to have_received(:find_cards_by_names).with([])
      end

      it "still imports the card" do
        expect {
          post deck_deck_imports_path(deck),
               params: { decklist: "1 Sol Ring" },
               headers: turbo_headers
        }.to change(DeckCard, :count).by(1)
      end
    end

    context "deck stats update after import" do
      before do
        allow(scryfall_service).to receive(:find_cards_by_names).and_return("Sol Ring" => card_data)
      end

      it "targets the deck_stats element for the turbo stream update" do
        post deck_deck_imports_path(deck),
             params: { decklist: "1 Sol Ring" },
             headers: turbo_headers

        expect(response.body).to match(%r{<turbo-stream action="update" target="deck_stats">})
      end

      it "renders the updated card count in the deck stats stream" do
        post deck_deck_imports_path(deck),
             params: { decklist: "1 Sol Ring" },
             headers: turbo_headers

        expect(response.body).to include("1 / 99 cards")
      end
    end

    context "Building Toward panel updates after import" do
      let!(:deck) { create(:deck, commander: commander, intent_completed: true) }

      before do
        allow(scryfall_service).to receive(:find_cards_by_names).and_return("Sol Ring" => card_data)
      end

      it "targets the building_toward element for the turbo stream update" do
        post deck_deck_imports_path(deck),
             params: { decklist: "1 Sol Ring" },
             headers: turbo_headers

        expect(response.body).to match(%r{<turbo-stream action="update" target="building_toward">})
      end

      it "reflects the newly imported card in the ratio counts" do
        post deck_deck_imports_path(deck),
             params: { decklist: "1 Sol Ring" },
             headers: turbo_headers

        expect(response.body).to include("Building Toward")
        expect(response.body).to include("1 / 10")
      end
    end

    context "when two lines resolve to the same card (e.g. different printings)" do
      before do
        allow(scryfall_service).to receive(:find_cards_by_names).and_return(
          "Island" => card_data.merge("id" => "scryfall-island", "name" => "Island", "type_line" => "Basic Land")
        )
      end

      it "sums quantities instead of overwriting" do
        post deck_deck_imports_path(deck),
             params: { decklist: "1 Island (WOE) 273\n2 Island (LCI) 271" },
             headers: turbo_headers

        expect(DeckCard.count).to eq(1)
        expect(DeckCard.last.quantity).to eq(3)
      end
    end
  end
end
