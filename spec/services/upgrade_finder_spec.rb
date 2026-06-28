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
      category:    "draw",
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
  let(:default_api_response) do
    instance_double(
      HTTParty::Response,
      success?: true,
      parsed_response: { "content" => [ { "text" => "A solid upgrade." } ] }
    )
  end

  before do
    allow(SuggestionEngine).to receive(:new).and_return(engine)
    allow(engine).to receive(:suggestions).and_return([
      { card: better_sorcery, score: 7, reasons: [ "Shares keyword: Flying" ] }
    ])
    # Bypass the validity gate by default so unrelated tests aren't affected by it.
    # Tests in the valid_suggestion? context override this with and_call_original.
    allow(Rails.cache).to receive(:fetch)
      .with(start_with("suggestion_valid"), anything)
      .and_return(true)
    allow(Rails.cache).to receive(:fetch)
      .with(start_with("upgrade_reason"), anything)
      .and_call_original
    allow(HTTParty).to receive(:post).and_return(default_api_response)
  end

  subject(:finder) { described_class.new(deck) }

  describe "#upgrades" do
    it "returns upgrades for low-synergy cards" do
      upgrades = finder.upgrades
      expect(upgrades).not_to be_empty
      expect(upgrades.first[:current_card]).to eq(weak_sorcery)
      expect(upgrades.first[:upgrade_card]["name"]).to eq("Treasure Cruise")
      expect(upgrades.first[:reason]).to be_a(String).and be_present
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

    context "valid_suggestion?" do
      let(:yes_response) do
        instance_double(
          HTTParty::Response,
          success?: true,
          parsed_response: { "content" => [ { "text" => "YES" } ] }
        )
      end
      let(:no_response) do
        instance_double(
          HTTParty::Response,
          success?: true,
          parsed_response: { "content" => [ { "text" => "NO" } ] }
        )
      end

      it "includes the suggestion when Claude responds YES" do
        allow(Rails.cache).to receive(:fetch)
          .with(start_with("suggestion_valid"), anything)
          .and_call_original
        allow(HTTParty).to receive(:post).and_return(yes_response, default_api_response)
        upgrades = finder.upgrades
        expect(upgrades).not_to be_empty
        expect(upgrades.first[:upgrade_card]["name"]).to eq("Treasure Cruise")
      end

      it "filters the suggestion when Claude responds NO" do
        allow(Rails.cache).to receive(:fetch)
          .with(start_with("suggestion_valid"), anything)
          .and_call_original
        allow(HTTParty).to receive(:post).and_return(no_response)
        expect(finder.upgrades).to be_empty
      end

      it "shows the suggestion when the validity API raises" do
        allow(Rails.cache).to receive(:fetch)
          .with(start_with("suggestion_valid"), anything)
          .and_call_original
        allow(HTTParty).to receive(:post).and_raise(StandardError, "timeout")
        expect(finder.upgrades).not_to be_empty
      end

      it "skips the validity API call on a cache hit" do
        # validity is already cached true by the outer before; only the reason call hits HTTParty
        expect(HTTParty).to receive(:post).once
        finder.upgrades
      end
    end

    context "generate_reason" do
      let(:claude_text) do
        "Treasure Cruise's Delve mechanic gives triple card draw at near-zero effective cost, far outpacing Divination for a Flying-focused build."
      end
      let(:claude_response) do
        instance_double(
          HTTParty::Response,
          success?: true,
          parsed_response: { "content" => [ { "text" => claude_text } ] }
        )
      end

      it "returns Claude-generated reasoning when the API succeeds" do
        allow(HTTParty).to receive(:post).and_return(claude_response)
        expect(finder.upgrades.first[:reason]).to eq(claude_text)
      end

      it "falls back to template string when the API raises" do
        allow(HTTParty).to receive(:post).and_raise(StandardError, "network timeout")
        reason = finder.upgrades.first[:reason]
        expect(reason).to start_with("Replaces Divination")
      end

      it "returns cached reason and skips the API on a cache hit" do
        cached = "Cached: Treasure Cruise is strictly better here."
        allow(Rails.cache).to receive(:fetch).and_return(cached)
        expect(HTTParty).not_to receive(:post)
        expect(finder.upgrades.first[:reason]).to eq(cached)
      end
    end
  end
end
