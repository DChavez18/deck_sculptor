require "rails_helper"

RSpec.describe SuggestionFilter, type: :service do
  def make_suggestion(overrides = {})
    card = {
      "id"             => overrides.fetch(:id, "card-1"),
      "name"           => overrides.fetch(:name, "Test Card"),
      "type_line"      => overrides.fetch(:type_line, "Creature — Elf"),
      "cmc"            => overrides.fetch(:cmc, 2.0),
      "color_identity" => overrides.fetch(:color_identity, [ "G" ]),
      "keywords"       => overrides.fetch(:keywords, []),
      "oracle_text"    => overrides.fetch(:oracle_text, "")
    }
    { card: card, score: overrides.fetch(:score, 5), reasons: [] }
  end

  let(:elf_druid)     { make_suggestion(id: "elf-1",     name: "Llanowar Elves",   type_line: "Creature — Elf Druid",  cmc: 1.0, color_identity: [ "G" ], keywords: []) }
  let(:elf_warrior)   { make_suggestion(id: "elf-2",     name: "Elvish Warrior",   type_line: "Creature — Elf Warrior", cmc: 2.0, color_identity: [ "G" ], keywords: []) }
  let(:blue_instant)  { make_suggestion(id: "instant-1", name: "Counterspell",     type_line: "Instant",                cmc: 2.0, color_identity: [ "U" ], keywords: []) }
  let(:sol_ring)      { make_suggestion(id: "sol-ring",  name: "Sol Ring",         type_line: "Artifact",               cmc: 1.0, color_identity: [],      keywords: []) }
  let(:flying_creature) { make_suggestion(id: "angel-1", name: "Serra Angel",      type_line: "Creature — Angel",       cmc: 5.0, color_identity: [ "W" ], keywords: [ "Flying", "Vigilance" ]) }

  let(:suggestions) { [ elf_druid, elf_warrior, blue_instant, sol_ring, flying_creature ] }

  describe "#apply" do
    context "when spec is nil" do
      it "returns all suggestions unchanged" do
        result = described_class.new(suggestions, nil).apply
        expect(result).to eq(suggestions)
      end
    end

    context "when filter_type is nil" do
      it "returns all suggestions unchanged" do
        spec   = { "filter_type" => nil }
        result = described_class.new(suggestions, spec).apply
        expect(result).to eq(suggestions)
      end
    end

    context "when filter_type is unknown" do
      it "returns all suggestions unchanged" do
        spec   = { "filter_type" => "unknown_type" }
        result = described_class.new(suggestions, spec).apply
        expect(result).to eq(suggestions)
      end
    end

    context "type filter" do
      context "filtering by subtype" do
        let(:spec) { { "filter_type" => "type", "subtypes" => [ "Elf" ] } }

        it "returns only cards whose type_line includes the subtype" do
          result = described_class.new(suggestions, spec).apply
          expect(result).to include(elf_druid, elf_warrior)
          expect(result).not_to include(blue_instant, sol_ring, flying_creature)
        end
      end

      context "filtering by card type" do
        let(:spec) { { "filter_type" => "type", "types" => [ "Instant" ] } }

        it "returns only Instants" do
          result = described_class.new(suggestions, spec).apply
          expect(result).to contain_exactly(blue_instant)
        end
      end

      context "filtering by color" do
        let(:spec) { { "filter_type" => "type", "colors" => [ "U" ] } }

        it "returns only cards that have the color in their identity" do
          result = described_class.new(suggestions, spec).apply
          expect(result).to contain_exactly(blue_instant)
        end
      end

      context "filtering by max_cmc" do
        let(:spec) { { "filter_type" => "type", "max_cmc" => 1 } }

        it "returns only cards with CMC <= max_cmc" do
          result = described_class.new(suggestions, spec).apply
          expect(result).to include(elf_druid, sol_ring)
          expect(result).not_to include(elf_warrior, blue_instant, flying_creature)
        end
      end

      context "filtering by min_cmc" do
        let(:spec) { { "filter_type" => "type", "min_cmc" => 5 } }

        it "returns only cards with CMC >= min_cmc" do
          result = described_class.new(suggestions, spec).apply
          expect(result).to contain_exactly(flying_creature)
        end
      end

      context "filtering by keyword" do
        let(:spec) { { "filter_type" => "type", "keywords" => [ "Flying" ] } }

        it "returns only cards that have the keyword" do
          result = described_class.new(suggestions, spec).apply
          expect(result).to contain_exactly(flying_creature)
        end
      end

      context "combining subtype and color filters" do
        let(:spec) { { "filter_type" => "type", "subtypes" => [ "Elf" ], "colors" => [ "G" ] } }

        it "applies both filters with AND logic" do
          result = described_class.new(suggestions, spec).apply
          expect(result).to include(elf_druid, elf_warrior)
          expect(result).not_to include(blue_instant, sol_ring)
        end
      end

      context "with empty suggestions pool" do
        it "returns an empty array" do
          spec   = { "filter_type" => "type", "subtypes" => [ "Elf" ] }
          result = described_class.new([], spec).apply
          expect(result).to eq([])
        end
      end
    end

    context "similarity filter" do
      # Sol Ring: Artifact, CMC 1, colorless, no keywords
      # To score >= 2 a card needs to match 2 of: subtype overlap, keyword overlap, CMC ±2, color overlap
      # Colorless artifact at CMC 1: scores 2 (subtype match via Artifact + CMC ±2) → included
      # Colorless artifact at CMC 8: CMC gap > 2, no subtype "Artifact" subtype → likely excluded

      let(:artifact_ramp)  { make_suggestion(id: "mana-vault",   name: "Mana Vault",   type_line: "Artifact",         cmc: 1.0, color_identity: [], keywords: []) }
      let(:distant_artifact) { make_suggestion(id: "bolas-citadel", name: "Bolas's Citadel", type_line: "Legendary Artifact", cmc: 6.0, color_identity: [ "B" ], keywords: []) }
      let(:green_elf)      { make_suggestion(id: "elf-3",         name: "Wirewood Herald",  type_line: "Creature — Elf",   cmc: 1.0, color_identity: [ "G" ], keywords: []) }

      let(:ref_card) do
        {
          "id"             => "sol-ring-ref",
          "name"           => "Sol Ring",
          "type_line"      => "Artifact",
          "cmc"            => 1.0,
          "color_identity" => [],
          "keywords"       => [],
          "oracle_text"    => "{T}: Add {C}{C}."
        }
      end

      let(:spec) { { "filter_type" => "similarity", "reference_card" => "Sol Ring" } }

      before do
        allow(CardCache).to receive(:fetch_by_name).with("Sol Ring").and_return(ref_card)
      end

      let(:pool) { [ artifact_ramp, distant_artifact, green_elf ] }

      it "includes Mana Vault (Artifact + CMC 1 = 2 signal matches)" do
        result = described_class.new(pool, spec).apply
        expect(result).to include(artifact_ramp)
      end

      it "excludes a distant artifact (high CMC, different color = only 1 match: Artifact subtype)" do
        # distant_artifact: subtype=Artifact(match), keyword(no), CMC 6 vs 1 > 2(no), color B vs none(no) → score 1 < 2
        result = described_class.new(pool, spec).apply
        expect(result).not_to include(distant_artifact)
      end

      it "excludes a green Elf creature (no subtype overlap, no keyword, CMC ±2 match, no color overlap = score 1)" do
        # green_elf: subtype Elf (no match), keyword(no), CMC 1 within ±2(yes), color G vs none(no) → score 1 < 2
        result = described_class.new(pool, spec).apply
        expect(result).not_to include(green_elf)
      end

      context "when the reference card cannot be found" do
        before do
          allow(CardCache).to receive(:fetch_by_name).with("Nonexistent Card").and_return(nil)
          allow(ScryfallService).to receive(:new).and_return(
            instance_double(ScryfallService, find_card_by_name: nil)
          )
        end

        it "returns all suggestions unchanged" do
          spec   = { "filter_type" => "similarity", "reference_card" => "Nonexistent Card" }
          result = described_class.new(pool, spec).apply
          expect(result).to eq(pool)
        end
      end

      context "Lightning Bolt as reference (cheap red instant)" do
        let(:lightning_bolt_ref) do
          { "id" => "lb-ref", "name" => "Lightning Bolt", "type_line" => "Instant",
            "cmc" => 1.0, "color_identity" => [ "R" ], "keywords" => [], "oracle_text" => "Deal 3 damage." }
        end
        let(:shock)    { make_suggestion(id: "shock",    name: "Shock",    type_line: "Instant",  cmc: 1.0, color_identity: [ "R" ], keywords: []) }
        let(:lava_axe) { make_suggestion(id: "lava-axe", name: "Lava Axe", type_line: "Sorcery",  cmc: 5.0, color_identity: [ "R" ], keywords: []) }
        let(:forest)   { make_suggestion(id: "forest",   name: "Forest",   type_line: "Basic Land — Forest", cmc: 0.0, color_identity: [ "G" ], keywords: []) }

        before do
          allow(CardCache).to receive(:fetch_by_name).with("Lightning Bolt").and_return(lightning_bolt_ref)
        end

        it "includes Shock (Instant + CMC 1 + red = 3 matches)" do
          result = described_class.new([ shock, lava_axe, forest ], { "filter_type" => "similarity", "reference_card" => "Lightning Bolt" }).apply
          expect(result).to include(shock)
        end

        it "excludes Forest (no type overlap, no keyword, CMC 1 vs 1 within ±2, color mismatch = score 1)" do
          # forest: subtype Forest vs Instant(no), keyword(no), CMC 0 within ±2(yes), color G vs R(no) → 1 < 2
          result = described_class.new([ shock, lava_axe, forest ], { "filter_type" => "similarity", "reference_card" => "Lightning Bolt" }).apply
          expect(result).not_to include(forest)
        end
      end

      context "Rhystic Study as reference (blue draw enchantment)" do
        let(:rhystic_ref) do
          { "id" => "rs-ref", "name" => "Rhystic Study", "type_line" => "Enchantment",
            "cmc" => 3.0, "color_identity" => [ "U" ], "keywords" => [], "oracle_text" => "Whenever an opponent casts a spell..." }
        end
        let(:mystic_remora) { make_suggestion(id: "mystic-r", name: "Mystic Remora", type_line: "Enchantment", cmc: 1.0, color_identity: [ "U" ], keywords: []) }
        let(:sol_ring_s)    { make_suggestion(id: "sol-r-s",  name: "Sol Ring",      type_line: "Artifact",     cmc: 1.0, color_identity: [],      keywords: []) }

        before do
          allow(CardCache).to receive(:fetch_by_name).with("Rhystic Study").and_return(rhystic_ref)
        end

        it "includes Mystic Remora (Enchantment + blue + CMC within ±2 = 3 matches)" do
          result = described_class.new(
            [ mystic_remora, sol_ring_s ],
            { "filter_type" => "similarity", "reference_card" => "Rhystic Study" }
          ).apply
          expect(result).to include(mystic_remora)
        end

        it "excludes Sol Ring (no Enchantment subtype, no color, CMC within ±2 = score 1)" do
          # sol_ring_s: subtype(no Enchantment), keyword(no), CMC 1 vs 3 within ±2(yes), color(no) → 1 < 2
          result = described_class.new(
            [ mystic_remora, sol_ring_s ],
            { "filter_type" => "similarity", "reference_card" => "Rhystic Study" }
          ).apply
          expect(result).not_to include(sol_ring_s)
        end
      end
    end

    context "combo filter" do
      let(:thassas_oracle_ref) { "Thassa's Oracle" }
      let(:spec) { { "filter_type" => "combo", "reference_card" => thassas_oracle_ref } }

      let(:combo_service) { instance_double(ComboFinderService) }

      let(:demonic_consultation) { make_suggestion(id: "dc-1", name: "Demonic Consultation", type_line: "Instant", cmc: 1.0, color_identity: [ "B" ]) }
      let(:tainted_pact)         { make_suggestion(id: "tp-1", name: "Tainted Pact",          type_line: "Instant", cmc: 2.0, color_identity: [ "B" ]) }
      let(:sol_ring_c)           { make_suggestion(id: "sr-c", name: "Sol Ring",              type_line: "Artifact", cmc: 1.0, color_identity: []) }

      let(:combos) do
        [
          { cards: [ "Thassa's Oracle", "Demonic Consultation" ], result: "Win the game", steps: "..." },
          { cards: [ "Thassa's Oracle", "Tainted Pact" ],         result: "Win the game", steps: "..." }
        ]
      end

      before do
        allow(ComboFinderService).to receive(:new).and_return(combo_service)
        allow(combo_service).to receive(:find_combos).with([ thassas_oracle_ref ]).and_return(combos)
      end

      let(:pool) { [ demonic_consultation, tainted_pact, sol_ring_c ] }

      it "returns only suggestion-pool cards that appear as combo partners" do
        result = described_class.new(pool, spec).apply
        expect(result).to include(demonic_consultation, tainted_pact)
        expect(result).not_to include(sol_ring_c)
      end

      it "is case-insensitive when matching partner names" do
        pool_with_caps = [
          make_suggestion(id: "dc-2", name: "DEMONIC CONSULTATION", type_line: "Instant", cmc: 1.0, color_identity: [ "B" ])
        ]
        result = described_class.new(pool_with_caps, spec).apply
        expect(result).to include(pool_with_caps.first)
      end

      context "when Commander Spellbook returns no combos" do
        before { allow(combo_service).to receive(:find_combos).and_return([]) }

        it "returns all suggestions unchanged" do
          result = described_class.new(pool, spec).apply
          expect(result).to eq(pool)
        end
      end

      context "when reference_card is blank" do
        let(:spec) { { "filter_type" => "combo", "reference_card" => "" } }

        it "returns all suggestions unchanged without calling ComboFinderService" do
          result = described_class.new(pool, spec).apply
          expect(result).to eq(pool)
          expect(ComboFinderService).not_to have_received(:new)
        end
      end
    end
  end
end
