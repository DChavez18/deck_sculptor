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
  let(:edhrec_service)   { instance_double(EdhrecService) }

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

  let(:combo_service)     { instance_double(ComboFinderService) }
  let(:cognition_service) { instance_double(CardCognitionService) }

  before do
    allow(ScryfallService).to receive(:new).and_return(scryfall_service)
    allow(scryfall_service).to receive(:commander_suggestions).and_return([ flying_creature, curve_filler, off_color_card ])
    allow(scryfall_service).to receive(:cards_by_color_identity).and_return([])
    allow(scryfall_service).to receive(:find_card_by_name).and_return(nil)
    allow(EdhrecService).to receive(:new).and_return(edhrec_service)
    allow(edhrec_service).to receive(:top_cards_with_details).and_return([])
    allow(ComboFinderService).to receive(:new).and_return(combo_service)
    allow(combo_service).to receive(:find_combos).and_return([])
    allow(CardCognitionService).to receive(:new).and_return(cognition_service)
    allow(cognition_service).to receive(:suggestions).and_return([])
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

    it "excludes cards already in the deck by scryfall_id" do
      create(:deck_card, deck: deck, scryfall_id: "card-flying")
      results = engine.suggestions
      ids = results.map { |r| r[:card]["id"] }
      expect(ids).not_to include("card-flying")
    end

    it "excludes cards already in the deck by card name" do
      create(:deck_card, deck: deck, scryfall_id: "other-id", card_name: "Angel of Mercy")
      results = engine.suggestions
      names = results.map { |r| r[:card]["name"] }
      expect(names).not_to include("Angel of Mercy")
    end

    it "excludes the commander card from suggestions" do
      commander_as_card = {
        "id"             => commander.scryfall_id,
        "name"           => commander.name,
        "type_line"      => "Legendary Creature — Human Wizard",
        "cmc"            => 4.0,
        "color_identity" => [ "W", "U" ],
        "keywords"       => [ "Flying" ],
        "oracle_text"    => ""
      }
      allow(scryfall_service).to receive(:commander_suggestions)
        .and_return([ commander_as_card, flying_creature ])
      results = engine.suggestions
      ids = results.map { |r| r[:card]["id"] }
      expect(ids).not_to include(commander.scryfall_id)
    end

    it "excludes the commander card from suggestions when matched by name" do
      commander_as_card = {
        "id"             => "some-other-id",
        "name"           => commander.name,
        "type_line"      => "Legendary Creature — Human Wizard",
        "cmc"            => 4.0,
        "color_identity" => [ "W", "U" ],
        "keywords"       => [],
        "oracle_text"    => ""
      }
      allow(scryfall_service).to receive(:commander_suggestions)
        .and_return([ commander_as_card, flying_creature ])
      results = engine.suggestions
      names = results.map { |r| r[:card]["name"] }
      expect(names).not_to include(commander.name)
    end

    it "excludes cards in deck.blacklisted_card_ids (thumbs down)" do
      deck.blacklist_card("card-flying")
      ids = engine.suggestions.map { |r| r[:card]["id"] }
      expect(ids).not_to include("card-flying")
    end

    it "does not exclude cards that have only thumbs-up feedback" do
      create(:suggestion_feedback, deck: deck, scryfall_id: "card-flying",
             card_name: "Angel of Mercy", feedback: "up")
      ids = engine.suggestions.map { |r| r[:card]["id"] }
      expect(ids).to include("card-flying")
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

    context "EDHREC pool seeding" do
      let(:edhrec_card) do
        {
          "id"             => "card-edhrec",
          "name"           => "Sol Ring",
          "type_line"      => "Artifact",
          "cmc"            => 1.0,
          "color_identity" => [],
          "keywords"       => [],
          "oracle_text"    => "{T}: Add {C}{C}."
        }
      end

      before do
        allow(edhrec_service).to receive(:top_cards_with_details).and_return([
          { name: "Sol Ring", synergy: 0.15, inclusion: 90000, category: "artifact", reason: "Popular with commander" }
        ])
        allow(scryfall_service).to receive(:find_card_by_name).with("Sol Ring").and_return(edhrec_card)
      end

      it "includes EDHREC top cards in the suggestion pool" do
        names = engine.suggestions.map { |r| r[:card]["name"] }
        expect(names).to include("Sol Ring")
      end

      it "deduplicates EDHREC cards already present in other pools" do
        allow(scryfall_service).to receive(:commander_suggestions).and_return([ edhrec_card ])
        names = engine.suggestions.map { |r| r[:card]["name"] }
        expect(names.count("Sol Ring")).to eq(1)
      end
    end
  end

  describe "#more_like" do
    let(:liked_card) do
      {
        "id"             => "liked-1",
        "name"           => "Sol Ring",
        "type_line"      => "Artifact",
        "cmc"            => 1.0,
        "keywords"       => [ "Flying" ],
        "oracle_text"    => "{T}: Add {C}{C}."
      }
    end

    let(:similar_card) do
      {
        "id"             => "similar-1",
        "name"           => "Arcane Signet",
        "type_line"      => "Artifact",
        "cmc"            => 2.0,
        "color_identity" => [ "U" ],
        "keywords"       => [ "Flying" ],
        "oracle_text"    => "{T}: Add one mana of any color in your commander's color identity."
      }
    end

    let(:unrelated_card) do
      {
        "id"             => "unrelated-1",
        "name"           => "Llanowar Elves",
        "type_line"      => "Creature — Elf Druid",
        "cmc"            => 1.0,
        "color_identity" => [ "G" ],
        "keywords"       => [],
        "oracle_text"    => "{T}: Add {G}."
      }
    end

    before do
      CardCache.store("liked-1", "Sol Ring", liked_card)
      allow(scryfall_service).to receive(:commander_suggestions).and_return([ similar_card, unrelated_card ])
    end

    it "returns cards matching keyword signals from liked cards" do
      results = engine.more_like([ "liked-1" ])
      names   = results.map { |r| r[:card]["name"] }
      expect(names).to include("Arcane Signet")
    end

    it "ranks keyword-matching cards above unrelated cards" do
      results  = engine.more_like([ "liked-1" ])
      similar  = results.find { |r| r[:card]["id"] == "similar-1" }
      unrelated = results.find { |r| r[:card]["id"] == "unrelated-1" }
      expect(similar[:score]).to be > unrelated[:score]
    end

    it "excludes cards that already have feedback for this deck" do
      create(:suggestion_feedback, deck: deck, scryfall_id: "similar-1",
             card_name: "Arcane Signet", feedback: "down")
      results = engine.more_like([ "liked-1" ])
      names   = results.map { |r| r[:card]["name"] }
      expect(names).not_to include("Arcane Signet")
    end

    it "returns at most 3 suggestions" do
      extra_cards = (1..5).map do |i|
        { "id" => "extra-#{i}", "name" => "Card #{i}", "type_line" => "Artifact",
          "cmc" => 1.0, "keywords" => [ "Flying" ], "oracle_text" => "" }
      end
      allow(scryfall_service).to receive(:commander_suggestions).and_return(extra_cards)
      results = engine.more_like([ "liked-1" ])
      expect(results.size).to be <= 3
    end

    it "returns empty array when scryfall_ids is empty" do
      expect(engine.more_like([])).to eq([])
    end

    it "excludes the liked cards themselves from results" do
      allow(scryfall_service).to receive(:commander_suggestions).and_return([ liked_card, similar_card ])
      results = engine.more_like([ "liked-1" ])
      ids     = results.map { |r| r[:card]["id"] }
      expect(ids).not_to include("liked-1")
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

    describe "+2 shared keyword with commander" do
      it "awards +2 to a card sharing a keyword" do
        result = engine.suggestions.find { |r| r[:card]["id"] == "card-flying" }
        expect(result[:score]).to be >= 2
        expect(result[:reasons]).to include(a_string_matching(/Flying/))
      end

      it "does not award keyword bonus when no keywords match" do
        result = engine.suggestions.find { |r| r[:card]["id"] == "card-curve" }
        expect(result[:reasons]).not_to include(a_string_matching(/Shares keyword/))
      end

      describe "qualified keyword specificity (e.g. amass Orcs vs amass Zombies)" do
        let(:sauron_commander) do
          create(:commander, raw_data: {
            "color_identity" => [ "B", "R", "W" ],
            "keywords"       => [ "Amass" ],
            "oracle_text"    => "Whenever you cast a spell, amass Orcs 1."
          })
        end
        let(:sauron_deck) { create(:deck, commander: sauron_commander) }
        subject(:sauron_engine) { described_class.new(sauron_deck) }

        let(:orc_amasser) do
          {
            "id"             => "card-orc-amass",
            "name"           => "Army of Mordor",
            "type_line"      => "Sorcery",
            "cmc"            => 3.0,
            "color_identity" => [ "B" ],
            "keywords"       => [ "Amass" ],
            "oracle_text"    => "amass Orcs 3."
          }
        end

        let(:zombie_amasser) do
          {
            "id"             => "card-zombie-amass",
            "name"           => "Zombie Horde",
            "type_line"      => "Sorcery",
            "cmc"            => 3.0,
            "color_identity" => [ "B" ],
            "keywords"       => [ "Amass" ],
            "oracle_text"    => "amass Zombies 3."
          }
        end

        before do
          allow(scryfall_service).to receive(:commander_suggestions).and_return([ orc_amasser, zombie_amasser ])
          allow(scryfall_service).to receive(:cards_by_color_identity).and_return([])
          allow(scryfall_service).to receive(:find_card_by_name).and_return(nil)
          allow(edhrec_service).to receive(:top_cards_with_details).and_return([])
          allow(combo_service).to receive(:find_combos).and_return([])
        end

        it "awards keyword synergy to a card with the matching qualified phrase" do
          result = sauron_engine.suggestions.find { |r| r[:card]["id"] == "card-orc-amass" }
          expect(result[:reasons]).to include(a_string_matching(/Shares keyword/))
        end

        it "does not award keyword synergy to a card with a different qualified noun" do
          result = sauron_engine.suggestions.find { |r| r[:card]["id"] == "card-zombie-amass" }
          expect(result[:reasons]).not_to include(a_string_matching(/Shares keyword/))
        end

        it "scores the matching-qualifier card higher than the non-matching one" do
          orc_result    = sauron_engine.suggestions.find { |r| r[:card]["id"] == "card-orc-amass" }
          zombie_result = sauron_engine.suggestions.find { |r| r[:card]["id"] == "card-zombie-amass" }
          expect(orc_result[:score]).to be > zombie_result[:score]
        end
      end
    end

    describe "+1 fills mana curve gap" do
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

    describe "+1 fills underrepresented category" do
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

    describe "tiered EDHREC synergy boost" do
      let(:staple_card) do
        {
          "id"             => "card-staple",
          "name"           => "Swords to Plowshares",
          "type_line"      => "Instant",
          "cmc"            => 1.0,
          "color_identity" => [ "W" ],
          "keywords"       => [],
          "oracle_text"    => "Exile target creature."
        }
      end

      before do
        allow(scryfall_service).to receive(:commander_suggestions).and_return([ staple_card, flying_creature ])
        allow(scryfall_service).to receive(:find_card_by_name).with("Swords to Plowshares").and_return(staple_card)
      end

      context "when synergy >= 0.3" do
        before do
          allow(edhrec_service).to receive(:top_cards_with_details).and_return([
            { name: "Swords to Plowshares", synergy: 0.35, inclusion: 60000, category: "removal", reason: "Popular with commander" }
          ])
        end

        it "awards +8 and tags 'High synergy staple'" do
          result = engine.suggestions.find { |r| r[:card]["id"] == "card-staple" }
          expect(result[:score]).to be >= 8
          expect(result[:reasons]).to include("High synergy staple")
        end
      end

      context "when synergy >= 0.1 but < 0.3" do
        before do
          allow(edhrec_service).to receive(:top_cards_with_details).and_return([
            { name: "Swords to Plowshares", synergy: 0.15, inclusion: 60000, category: "removal", reason: "Popular with commander" }
          ])
        end

        it "awards +6 and tags 'Commander staple'" do
          result = engine.suggestions.find { |r| r[:card]["id"] == "card-staple" }
          expect(result[:score]).to be >= 6
          expect(result[:reasons]).to include("Commander staple")
        end
      end

      context "when synergy > 0 but < 0.1" do
        before do
          allow(edhrec_service).to receive(:top_cards_with_details).and_return([
            { name: "Swords to Plowshares", synergy: 0.05, inclusion: 60000, category: "removal", reason: "Popular with commander" }
          ])
        end

        it "awards +4 and tags 'Popular pick'" do
          result = engine.suggestions.find { |r| r[:card]["id"] == "card-staple" }
          expect(result[:score]).to be >= 4
          expect(result[:reasons]).to include("Popular pick")
        end
      end

      context "when a card is not in the EDHREC list" do
        before do
          allow(edhrec_service).to receive(:top_cards_with_details).and_return([
            { name: "Swords to Plowshares", synergy: 0.35, inclusion: 60000, category: "removal", reason: "Popular with commander" }
          ])
        end

        it "does not award any EDHREC boost" do
          result = engine.suggestions.find { |r| r[:card]["id"] == "card-flying" }
          expect(result[:reasons]).not_to include("High synergy staple", "Commander staple", "Popular pick")
        end
      end
    end

    describe "+1/+2 theme keyword boost" do
      let(:token_card) do
        {
          "id"             => "card-token",
          "name"           => "Anointed Procession",
          "type_line"      => "Enchantment",
          "cmc"            => 4.0,
          "color_identity" => [ "W" ],
          "keywords"       => [],
          "oracle_text"    => "If an effect would create one or more tokens under your control, it creates twice that many of those tokens instead."
        }
      end

      before do
        allow(scryfall_service).to receive(:commander_suggestions).and_return([ token_card ])
      end

      context "when deck has a matching theme keyword" do
        let(:deck) { create(:deck, commander: commander, themes: "tokens, aristocrats") }

        it "awards +1 per matching keyword up to +2" do
          result = engine.suggestions.find { |r| r[:card]["id"] == "card-token" }
          expect(result[:score]).to be >= 1
          expect(result[:reasons]).to include("Matches your theme: tokens")
        end

        it "caps boost at +2 for two matching themes" do
          two_theme_card = token_card.merge(
            "id"          => "card-two-themes",
            "oracle_text" => "tokens aristocrats"
          )
          allow(scryfall_service).to receive(:commander_suggestions).and_return([ two_theme_card ])
          result = engine.suggestions.find { |r| r[:card]["id"] == "card-two-themes" }
          theme_score = result[:reasons].count { |r| r.start_with?("Matches your theme") }
          expect(theme_score).to be <= 2
        end
      end

      context "when deck has no themes set" do
        let(:deck) { create(:deck, commander: commander, themes: nil) }

        it "awards no theme boost" do
          result = engine.suggestions.find { |r| r[:card]["id"] == "card-token" }
          expect(result[:reasons]).not_to include(a_string_matching(/Matches your theme/))
        end
      end

      context "when card does not match any theme keyword" do
        let(:deck) { create(:deck, commander: commander, themes: "graveyard, reanimator") }

        it "awards no theme boost to an unrelated card" do
          result = engine.suggestions.find { |r| r[:card]["id"] == "card-token" }
          expect(result[:reasons]).not_to include(a_string_matching(/Matches your theme/))
        end
      end
    end

    describe "+2 liked_ids synergy boost" do
      let(:liked_card) do
        { "id" => "liked-1", "name" => "Liked Artifact", "type_line" => "Artifact",
          "cmc" => 2.0, "keywords" => [ "Flying" ], "oracle_text" => "" }
      end

      let(:matching_card) do
        { "id"             => "card-match",
          "name"           => "Matching Artifact",
          "type_line"      => "Artifact",
          "cmc"            => 2.0,
          "color_identity" => [ "U" ],
          "keywords"       => [ "Flying" ],
          "oracle_text"    => "" }
      end

      before do
        CardCache.store("liked-1", "Liked Artifact", liked_card)
        allow(scryfall_service).to receive(:commander_suggestions).and_return([ matching_card ])
      end

      context "when liked_ids are provided" do
        subject(:engine) { described_class.new(deck, liked_ids: [ "liked-1" ]) }

        it "adds +2 to cards sharing liked keywords" do
          result = engine.suggestions.find { |r| r[:card]["id"] == "card-match" }
          expect(result[:score]).to be >= 2
          expect(result[:reasons]).to include("Synergizes with your picks")
        end
      end

      context "when liked_ids is empty (default)" do
        it "does not apply the synergy boost" do
          result = engine.suggestions.find { |r| r[:card]["id"] == "card-match" }
          expect(result[:reasons]).not_to include("Synergizes with your picks")
        end
      end
    end

    describe "CardCognition synergy boost" do
      let(:high_synergy_card) do
        {
          "id"             => "card-cognition-high",
          "name"           => "Deepglow Skate",
          "type_line"      => "Creature — Fish",
          "cmc"            => 5.0,
          "color_identity" => [ "U" ],
          "keywords"       => [],
          "oracle_text"    => "When Deepglow Skate enters the battlefield, double the number of each kind of counter on any number of target permanents."
        }
      end

      let(:moderate_synergy_card) do
        {
          "id"             => "card-cognition-mid",
          "name"           => "Inexorable Tide",
          "type_line"      => "Enchantment",
          "cmc"            => 5.0,
          "color_identity" => [ "U" ],
          "keywords"       => [],
          "oracle_text"    => "Whenever you cast a spell, proliferate."
        }
      end

      before do
        allow(cognition_service).to receive(:suggestions).and_return([
          { "name" => "Deepglow Skate", "score" => 0.75, "scryfall_id" => "card-cognition-high" },
          { "name" => "Inexorable Tide", "score" => 0.30, "scryfall_id" => "card-cognition-mid" }
        ])
        allow(scryfall_service).to receive(:find_card_by_name).with("Deepglow Skate").and_return(high_synergy_card)
        allow(scryfall_service).to receive(:find_card_by_name).with("Inexorable Tide").and_return(moderate_synergy_card)
        allow(scryfall_service).to receive(:commander_suggestions).and_return([ high_synergy_card, moderate_synergy_card ])
      end

      it "awards +3 and 'High commander synergy' for score >= 0.5" do
        result = engine.suggestions.find { |r| r[:card]["id"] == "card-cognition-high" }
        expect(result[:score]).to be >= 3
        expect(result[:reasons]).to include("High commander synergy")
      end

      it "awards +2 and 'Commander synergy' for score >= 0.2 but < 0.5" do
        result = engine.suggestions.find { |r| r[:card]["id"] == "card-cognition-mid" }
        expect(result[:score]).to be >= 2
        expect(result[:reasons]).to include("Commander synergy")
      end

      it "excludes CardCognition cards already in the deck" do
        create(:deck_card, deck: deck, scryfall_id: "card-cognition-high", card_name: "Deepglow Skate")
        ids = engine.suggestions.map { |r| r[:card]["id"] }
        expect(ids).not_to include("card-cognition-high")
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
