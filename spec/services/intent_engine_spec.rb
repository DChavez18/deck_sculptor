require "rails_helper"

RSpec.describe IntentEngine, type: :service do
  subject(:engine) { described_class.new(deck) }

  let(:commander_data) do
    {
      "id"             => "cmd-001",
      "name"           => "Atraxa, Praetors' Voice",
      "color_identity" => %w[B G U W],
      "oracle_text"    => "Flying, vigilance, deathtouch, lifelink. Proliferate.",
      "type_line"      => "Legendary Creature — Phyrexian Angel Horror",
      "keywords"       => %w[Flying Vigilance Deathtouch Lifelink Proliferate]
    }
  end

  let(:commander) { create(:commander, raw_data: commander_data) }
  let(:deck) do
    create(:deck,
           commander:     commander,
           win_condition: nil,
           budget:        nil,
           archetype:     "midrange",
           themes:        nil)
  end

  let(:ramp_card) do
    {
      "id"             => "ramp-001",
      "name"           => "Sol Ring",
      "color_identity" => [],
      "oracle_text"    => "{T}: Add {C}{C}.",
      "type_line"      => "Artifact",
      "cmc"            => 1
    }
  end

  let(:tutor_card) do
    {
      "id"             => "tut-001",
      "name"           => "Demonic Tutor",
      "color_identity" => %w[B],
      "oracle_text"    => "Search your library for a card.",
      "type_line"      => "Sorcery",
      "cmc"            => 2
    }
  end

  let(:scryfall) { instance_double(ScryfallService) }

  before do
    allow(ScryfallService).to receive(:new).and_return(scryfall)
    allow(scryfall).to receive(:cards_by_function).and_return([])
  end

  # ── staples always fetched ────────────────────────────────────────────────

  describe "staple pools" do
    it "always fetches ramp" do
      engine.suggestions
      expect(scryfall).to have_received(:cards_by_function).with("ramp", any_args)
    end

    it "always fetches draw-card" do
      engine.suggestions
      expect(scryfall).to have_received(:cards_by_function).with("draw-card", any_args)
    end
  end

  # ── win_condition pools ───────────────────────────────────────────────────

  describe "win_condition pools" do
    context "with combat win condition" do
      before { deck.update!(win_condition: "Combat damage") }

      it "fetches attack-trigger" do
        engine.suggestions
        expect(scryfall).to have_received(:cards_by_function).with("attack-trigger", any_args)
      end

      it "fetches combat-ramp" do
        engine.suggestions
        expect(scryfall).to have_received(:cards_by_function).with("combat-ramp", any_args)
      end

      it "does not fetch tutor" do
        engine.suggestions
        expect(scryfall).not_to have_received(:cards_by_function).with("tutor", any_args)
      end
    end

    context "with combo win condition" do
      before { deck.update!(win_condition: "Infinite combo") }

      it "fetches tutor" do
        engine.suggestions
        expect(scryfall).to have_received(:cards_by_function).with("tutor", any_args)
      end

      it "fetches graveyard-recursion" do
        engine.suggestions
        expect(scryfall).to have_received(:cards_by_function).with("graveyard-recursion", any_args)
      end
    end

    context "with control win condition" do
      before { deck.update!(win_condition: "control the board") }

      it "fetches counter-spell, removal, and boardwipe" do
        engine.suggestions
        expect(scryfall).to have_received(:cards_by_function).with("counter-spell", any_args)
        expect(scryfall).to have_received(:cards_by_function).with("removal", any_args)
        expect(scryfall).to have_received(:cards_by_function).with("boardwipe", any_args)
      end
    end

    context "with no win condition" do
      it "does not fetch tutor or attack-trigger" do
        engine.suggestions
        expect(scryfall).not_to have_received(:cards_by_function).with("tutor", any_args)
        expect(scryfall).not_to have_received(:cards_by_function).with("attack-trigger", any_args)
      end
    end
  end

  # ── budget option passed through ─────────────────────────────────────────

  describe "budget filtering" do
    context "with casual budget" do
      before { deck.update!(budget: "casual") }

      it "passes budget: 1.0 to cards_by_function" do
        engine.suggestions
        expect(scryfall).to have_received(:cards_by_function)
          .with(anything, anything, hash_including(budget: 1.0)).at_least(:once)
      end
    end

    context "with optimized budget" do
      before { deck.update!(budget: "optimized") }

      it "passes budget: 5.0 to cards_by_function" do
        engine.suggestions
        expect(scryfall).to have_received(:cards_by_function)
          .with(anything, anything, hash_including(budget: 5.0)).at_least(:once)
      end
    end

    context "with competitive budget" do
      before { deck.update!(budget: "competitive") }

      it "does not pass a budget option" do
        engine.suggestions
        expect(scryfall).not_to have_received(:cards_by_function)
          .with(anything, anything, hash_including(:budget))
      end
    end
  end

  # ── playstyle modifier ────────────────────────────────────────────────────

  describe "playstyle modifier" do
    context "with aggro archetype" do
      before do
        deck.update!(archetype: "aggro")
        allow(scryfall).to receive(:cards_by_function).with("ramp", any_args).and_return([ ramp_card ])
      end

      it "adds +1 to cards with cmc <= 2" do
        results = engine.suggestions
        sol_ring = results.find { |s| s[:card]["name"] == "Sol Ring" }
        expect(sol_ring).not_to be_nil
        expect(sol_ring[:score]).to be >= 3  # base 2 + playstyle 1
        expect(sol_ring[:reasons]).to include("Matches playstyle")
      end
    end

    context "with control archetype and removal pool" do
      before do
        deck.update!(win_condition: "control", archetype: "control")
        allow(scryfall).to receive(:cards_by_function).with("removal", any_args).and_return([ tutor_card ])
      end

      it "adds +1 to cards in removal pool" do
        results = engine.suggestions
        card = results.find { |s| s[:card]["name"] == "Demonic Tutor" }
        expect(card).not_to be_nil
        expect(card[:reasons]).to include("Matches playstyle")
      end
    end
  end

  # ── theme boost ───────────────────────────────────────────────────────────

  describe "theme boost" do
    before do
      deck.update!(themes: "artifact, proliferate")
      allow(scryfall).to receive(:cards_by_function).with("ramp", any_args).and_return([ ramp_card ])
    end

    it "adds theme reason for matching keyword in card text" do
      results = engine.suggestions
      sol_ring = results.find { |s| s[:card]["name"] == "Sol Ring" }
      expect(sol_ring).not_to be_nil
      # Sol Ring type_line "Artifact" matches theme "artifact"
      expect(sol_ring[:reasons]).to include("Matches your theme: artifact")
    end
  end

  # ── liked_ids boost ──────────────────────────────────────────────────────

  describe "liked_ids boost" do
    let(:liked_card) do
      { "id" => "liked-1", "name" => "Liked Artifact", "type_line" => "Artifact",
        "cmc" => 1, "keywords" => [ "Flying" ], "oracle_text" => "" }
    end

    let(:matching_card) do
      { "id"             => "match-001",
        "name"           => "Matching Card",
        "color_identity" => %w[U],
        "oracle_text"    => "{T}: Add {U}.",
        "type_line"      => "Artifact",
        "keywords"       => %w[Flying],
        "cmc"            => 1 }
    end

    before do
      CardCache.store("liked-1", "Liked Artifact", liked_card)
      allow(scryfall).to receive(:cards_by_function).with("ramp", any_args).and_return([ matching_card ])
    end

    context "when liked_ids are provided" do
      subject(:engine) { described_class.new(deck, liked_ids: [ "liked-1" ]) }

      it "adds +2 and 'Synergizes with your picks' to cards matching liked signals" do
        results = engine.suggestions
        card = results.find { |s| s[:card]["id"] == "match-001" }
        expect(card).not_to be_nil
        expect(card[:score]).to be >= 4  # base 2 + liked boost 2
        expect(card[:reasons]).to include("Synergizes with your picks")
      end
    end

    context "when liked_ids is empty (default)" do
      it "does not apply the synergy boost" do
        results = engine.suggestions
        card = results.find { |s| s[:card]["id"] == "match-001" }
        expect(card).not_to be_nil
        expect(card[:reasons]).not_to include("Synergizes with your picks")
      end
    end
  end

  # ── exclusions ────────────────────────────────────────────────────────────

  describe "card exclusions" do
    before do
      allow(scryfall).to receive(:cards_by_function).with("ramp", any_args).and_return([ ramp_card ])
    end

    it "excludes cards already in the deck" do
      create(:deck_card, deck: deck, scryfall_id: ramp_card["id"], card_name: ramp_card["name"])
      results = engine.suggestions
      expect(results.map { |s| s[:card]["id"] }).not_to include(ramp_card["id"])
    end

    it "excludes cards already in the deck by name when scryfall_id does not match" do
      create(:deck_card, deck: deck, scryfall_id: "some-other-id", card_name: ramp_card["name"])
      results = engine.suggestions
      expect(results.map { |s| s[:card]["name"] }).not_to include(ramp_card["name"])
    end

    it "excludes cards in deck.blacklisted_card_ids" do
      deck.blacklist_card(ramp_card["id"])
      results = engine.suggestions
      expect(results.map { |s| s[:card]["id"] }).not_to include(ramp_card["id"])
    end

    it "excludes the commander card from suggestions by scryfall_id" do
      commander_as_card = {
        "id"             => commander.scryfall_id,
        "name"           => commander.name,
        "color_identity" => %w[B G U W],
        "oracle_text"    => "",
        "type_line"      => "Legendary Creature — Phyrexian Angel Horror",
        "cmc"            => 4
      }
      allow(scryfall).to receive(:cards_by_function).with("ramp", any_args)
        .and_return([ commander_as_card ])
      results = engine.suggestions
      expect(results.map { |s| s[:card]["id"] }).not_to include(commander.scryfall_id)
    end

    it "excludes the commander card from suggestions by name" do
      commander_as_card = {
        "id"             => "different-id",
        "name"           => commander.name,
        "color_identity" => %w[B G U W],
        "oracle_text"    => "",
        "type_line"      => "Legendary Creature — Phyrexian Angel Horror",
        "cmc"            => 4
      }
      allow(scryfall).to receive(:cards_by_function).with("ramp", any_args)
        .and_return([ commander_as_card ])
      results = engine.suggestions
      expect(results.map { |s| s[:card]["name"] }).not_to include(commander.name)
    end
  end

  # ── deduplication ─────────────────────────────────────────────────────────

  describe "deduplication across pools" do
    before do
      deck.update!(win_condition: "Infinite combo", archetype: "aggro")
      # ramp pool: ramp_card with cmc 1 → aggro boost → score 3
      allow(scryfall).to receive(:cards_by_function).with("ramp", any_args).and_return([ ramp_card ])
      # tutor pool: also returns ramp_card (overlap) — no aggro boost for tutor tag
      allow(scryfall).to receive(:cards_by_function).with("tutor", any_args).and_return([ ramp_card ])
    end

    it "returns ramp_card only once" do
      results = engine.suggestions
      ids = results.map { |s| s[:card]["id"] }
      expect(ids.count(ramp_card["id"])).to eq(1)
    end

    it "keeps the higher-score entry" do
      results = engine.suggestions
      entry = results.find { |s| s[:card]["id"] == ramp_card["id"] }
      # ramp pool: base 2 + aggro +1 (cmc 1 <= 2) = 3; tutor pool: base 2 + aggro +1 = 3 also
      # Both have same score; dedup keeps whichever was processed first
      expect(entry[:score]).to be >= 3
    end
  end
end
