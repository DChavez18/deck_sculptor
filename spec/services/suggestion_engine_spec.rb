require "rails_helper"

RSpec.describe SuggestionEngine do
  let(:commander) do
    create(:commander, raw_data: {
      "color_identity" => [ "W", "U" ],
      "keywords"       => [ "Flying" ]
    })
  end
  let(:deck)   { create(:deck, commander: commander) }
  subject(:engine) { described_class.new(deck) }

  let(:scryfall_service) { instance_double(ScryfallService) }

  let(:flying_creature) do
    {
      "id"             => "card-flying",
      "name"           => "Angel of Mercy",
      "type_line"      => "Creature — Angel",
      "cmc"            => 3.0,
      "color_identity" => [ "W" ],
      "keywords"       => [ "Flying", "Lifelink" ],
      "oracle_text"    => "Flying, lifelink",
      "image_uris"     => { "normal" => "https://example.com/angel.jpg" }
    }
  end

  let(:curve_filler) do
    {
      "id"             => "card-curve",
      "name"           => "Counterspell",
      "type_line"      => "Instant",
      "cmc"            => 2.0,
      "color_identity" => [ "U" ],
      "keywords"       => [],
      "oracle_text"    => "Counter target spell.",
      "image_uris"     => { "normal" => "https://example.com/counter.jpg" }
    }
  end

  let(:off_color_card) do
    {
      "id"             => "card-off-color",
      "name"           => "Lightning Bolt",
      "type_line"      => "Instant",
      "cmc"            => 1.0,
      "color_identity" => [ "R" ],
      "keywords"       => [],
      "oracle_text"    => "Deal 3 damage.",
      "image_uris"     => {}
    }
  end

  let(:combo_service) { instance_double(ComboFinderService) }

  before do
    allow(ScryfallService).to receive(:new).and_return(scryfall_service)
    allow(scryfall_service).to receive(:commander_suggestions).and_return([ flying_creature, curve_filler, off_color_card ])
    allow(scryfall_service).to receive(:cards_by_color_identity).and_return([])
    allow(ComboFinderService).to receive(:new).and_return(combo_service)
    allow(combo_service).to receive(:find_combos).and_return([])
  end

  describe "#suggestions" do
    it "returns an array of hashes with card, score, and reasons keys" do
      results = engine.suggestions
      expect(results).to be_an(Array)
      expect(results.first).to include(:card, :score, :reasons)
    end

    it "sorts results by score descending" do
      results = engine.suggestions
      scores = results.map { |r| r[:score] }
      expect(scores).to eq(scores.sort.reverse)
    end

    it "excludes cards already in the deck" do
      create(:deck_card, deck: deck, scryfall_id: "card-flying")
      results = engine.suggestions
      ids = results.map { |r| r[:card]["id"] }
      expect(ids).not_to include("card-flying")
    end

    it "merges suggestions from commander_suggestions and cards_by_color_identity" do
      extra_card = {
        "id"             => "card-extra",
        "name"           => "Extra Card",
        "type_line"      => "Instant",
        "cmc"            => 1.0,
        "color_identity" => [ "U" ],
        "keywords"       => [],
        "oracle_text"    => ""
      }
      allow(scryfall_service).to receive(:cards_by_color_identity).and_return([ extra_card ])
      ids = engine.suggestions.map { |r| r[:card]["id"] }
      expect(ids).to include("card-extra")
    end

    it "deduplicates cards appearing in both pools" do
      allow(scryfall_service).to receive(:cards_by_color_identity).and_return([ flying_creature ])
      ids = engine.suggestions.map { |r| r[:card]["id"] }
      expect(ids.count("card-flying")).to eq(1)
    end
  end

  describe "scoring" do
    describe "+1 within color identity" do
      it "awards +1 to in-color cards" do
        result = engine.suggestions.find { |r| r[:card]["id"] == "card-flying" }
        expect(result[:reasons]).to include("Within color identity")
      end

      it "does not award +1 to off-color cards" do
        result = engine.suggestions.find { |r| r[:card]["id"] == "card-off-color" }
        expect(result[:reasons]).not_to include("Within color identity")
      end

      it "awards +1 to colorless cards regardless of commander colors" do
        colorless = {
          "id"             => "card-colorless",
          "name"           => "Sol Ring",
          "type_line"      => "Artifact",
          "cmc"            => 1.0,
          "color_identity" => [],
          "keywords"       => [],
          "oracle_text"    => "{T}: Add {C}{C}."
        }
        allow(scryfall_service).to receive(:commander_suggestions).and_return([ colorless ])
        result = engine.suggestions.find { |r| r[:card]["id"] == "card-colorless" }
        expect(result[:reasons]).to include("Within color identity")
      end
    end

    describe "+3 shared keyword with commander" do
      it "awards +3 to a card sharing a keyword" do
        result = engine.suggestions.find { |r| r[:card]["id"] == "card-flying" }
        expect(result[:score]).to be >= 3
        expect(result[:reasons]).to include(a_string_matching(/Flying/))
      end

      it "does not award keyword bonus when no keywords match" do
        result = engine.suggestions.find { |r| r[:card]["id"] == "card-curve" }
        expect(result[:reasons]).not_to include(a_string_matching(/Shares keyword/))
      end
    end

    describe "+2 fills mana curve gap" do
      before do
        # Fill cmc slots 1, 3, 4, 5, 6 — leaving cmc 2 as the gap
        create(:deck_card, deck: deck, cmc: 1.0, category: "instant")
        create(:deck_card, deck: deck, cmc: 3.0, category: "instant")
        create(:deck_card, deck: deck, cmc: 4.0, category: "instant")
        create(:deck_card, deck: deck, cmc: 5.0, category: "instant")
        create(:deck_card, deck: deck, cmc: 6.0, category: "instant")
      end

      it "awards +2 to a card at the gap cmc" do
        result = engine.suggestions.find { |r| r[:card]["id"] == "card-curve" }
        expect(result[:reasons]).to include("Fills mana curve gap at 2")
      end

      it "does not award curve bonus for other cmc slots" do
        result = engine.suggestions.find { |r| r[:card]["id"] == "card-flying" }
        expect(result[:reasons]).not_to include(a_string_matching(/mana curve gap at 2/))
      end
    end

    describe "+2 fills underrepresented category" do
      context "when deck has fewer than 10 creatures" do
        it "awards +2 to creature cards" do
          result = engine.suggestions.find { |r| r[:card]["id"] == "card-flying" }
          expect(result[:reasons]).to include("Fills underrepresented category")
        end

        it "does not award +2 to non-creature cards" do
          result = engine.suggestions.find { |r| r[:card]["id"] == "card-curve" }
          expect(result[:reasons]).not_to include("Fills underrepresented category")
        end
      end

      context "when deck already has 10 or more creatures" do
        before do
          create_list(:deck_card, 10, deck: deck, category: "creature", quantity: 1)
        end

        it "does not award +2 for creature cards" do
          result = engine.suggestions.find { |r| r[:card]["id"] == "card-flying" }
          expect(result[:reasons]).not_to include("Fills underrepresented category")
        end
      end
    end

    describe "+3 combo piece" do
      let(:combo_card) do
        {
          "id"             => "card-combo",
          "name"           => "Thassa's Oracle",
          "type_line"      => "Creature — Merfolk Wizard",
          "cmc"            => 2.0,
          "color_identity" => [ "U" ],
          "keywords"       => [],
          "oracle_text"    => "When Thassa's Oracle enters..."
        }
      end

      before do
        allow(scryfall_service).to receive(:commander_suggestions).and_return([ combo_card ])
        create(:deck_card, deck: deck, card_name: "Demonic Consultation")
        create(:deck_card, deck: deck, card_name: "Laboratory Maniac")
      end

      context "when 2+ combo partners are already in the deck" do
        before do
          allow(combo_service).to receive(:find_combos).and_return([
            { cards: [ "Thassa's Oracle", "Demonic Consultation", "Laboratory Maniac" ], result: "Win the game", steps: "" }
          ])
        end

        it "awards +3 to the card" do
          result = engine.suggestions.find { |r| r[:card]["id"] == "card-combo" }
          expect(result[:score]).to be >= 3
          expect(result[:reasons]).to include("Combo piece")
        end
      end

      context "when fewer than 2 combo partners are in the deck" do
        before do
          allow(combo_service).to receive(:find_combos).and_return([
            { cards: [ "Thassa's Oracle", "Demonic Consultation" ], result: "Win the game", steps: "" }
          ])
        end

        it "does not award the combo bonus" do
          result = engine.suggestions.find { |r| r[:card]["id"] == "card-combo" }
          expect(result[:reasons]).not_to include("Combo piece")
        end
      end

      context "when the card is not part of any combo" do
        before do
          allow(combo_service).to receive(:find_combos).and_return([
            { cards: [ "Demonic Consultation", "Laboratory Maniac", "Unrelated Card" ], result: "Win the game", steps: "" }
          ])
        end

        it "does not award the combo bonus" do
          result = engine.suggestions.find { |r| r[:card]["id"] == "card-combo" }
          expect(result[:reasons]).not_to include("Combo piece")
        end
      end
    end
  end
end
