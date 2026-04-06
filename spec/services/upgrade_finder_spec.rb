require "rails_helper"

RSpec.describe UpgradeFinder do
  let(:commander) do
    create(:commander, raw_data: {
      "color_identity" => [ "U" ],
      "keywords"       => [ "Flying" ]
    })
  end
  let(:deck)          { create(:deck, commander: commander, themes: "proliferate") }
  let!(:weak_sorcery) do
    create(:deck_card, deck: deck,
      card_name:   "Divination",
      category:    "sorcery",
      oracle_text: "Draw two cards.",
      raw_data:    { "keywords" => [] })
  end

  let(:better_sorcery) do
    {
      "id"             => "better-sorcery-id",
      "name"           => "Treasure Cruise",
      "type_line"      => "Sorcery",
      "cmc"            => 8.0,
      "color_identity" => [ "U" ],
      "keywords"       => [ "Flying" ],
      "oracle_text"    => "Flying. Draw three cards.",
      "image_uris"     => {}
    }
  end

  let(:engine) { instance_double(SuggestionEngine) }

  before do
    allow(SuggestionEngine).to receive(:new).and_return(engine)
    allow(engine).to receive(:suggestions).and_return([
      { card: better_sorcery, score: 7, reasons: [ "Shares keyword: Flying" ] }
    ])
  end

  subject(:finder) { described_class.new(deck) }

  describe "#upgrades" do
    it "returns upgrades for low-synergy cards" do
      upgrades = finder.upgrades
      expect(upgrades).not_to be_empty
      expect(upgrades.first[:current_card]).to eq(weak_sorcery)
      expect(upgrades.first[:upgrade_card]["name"]).to eq("Treasure Cruise")
      expect(upgrades.first[:reason]).to include("Divination")
    end

    it "excludes cards already in the deck from upgrade suggestions" do
      in_deck = better_sorcery.merge("id" => weak_sorcery.scryfall_id)
      allow(engine).to receive(:suggestions).and_return([
        { card: in_deck, score: 8, reasons: [] }
      ])
      expect(finder.upgrades).to be_empty
    end

    it "excludes suggestions below the score threshold" do
      allow(engine).to receive(:suggestions).and_return([
        { card: better_sorcery, score: 4, reasons: [] }
      ])
      expect(finder.upgrades).to be_empty
    end

    it "caps at 5 upgrades" do
      many_cards = Array.new(10) do |i|
        {
          "id"             => "card-#{i}",
          "name"           => "Good Card #{i}",
          "type_line"      => "Sorcery",
          "cmc"            => 2.0,
          "color_identity" => [ "U" ],
          "keywords"       => [ "Flying" ],
          "oracle_text"    => "Flying. Draw a card.",
          "image_uris"     => {}
        }
      end
      Array.new(10) { |i| create(:deck_card, deck: deck, card_name: "Weak Card #{i}", category: "sorcery", oracle_text: "Do nothing.", raw_data: { "keywords" => [] }) }
      allow(engine).to receive(:suggestions).and_return(
        many_cards.map { |c| { card: c, score: 8, reasons: [] } }
      )

      expect(finder.upgrades.size).to be <= 5
    end

    it "returns empty when deck has no cards" do
      empty_deck = create(:deck, commander: commander)
      allow(SuggestionEngine).to receive(:new).and_return(engine)
      expect(described_class.new(empty_deck).upgrades).to eq([])
    end
  end
end
