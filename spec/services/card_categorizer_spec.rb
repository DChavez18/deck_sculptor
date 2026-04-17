require "rails_helper"

RSpec.describe CardCategorizer do
  subject(:categorizer) { described_class.new(card) }

  describe "#category" do
    # --- Land ---
    context "when type_line is a basic land" do
      let(:card) { { "type_line" => "Basic Land — Island" } }

      it { expect(categorizer.category).to eq("land") }
    end

    context "when type_line is a non-basic land" do
      let(:card) { { "type_line" => "Land — Forest" } }

      it { expect(categorizer.category).to eq("land") }
    end

    # --- Ramp ---
    context "Sol Ring — taps to add mana" do
      let(:card) { { "type_line" => "Artifact", "oracle_text" => "{T}: Add {C}{C}." } }

      it { expect(categorizer.category).to eq("ramp") }
    end

    context "Arcane Signet — taps to add mana" do
      let(:card) { { "type_line" => "Artifact", "oracle_text" => "{T}: Add one mana of any color in your commander's color identity." } }

      it { expect(categorizer.category).to eq("ramp") }
    end

    context "Thought Vessel — taps to add mana" do
      let(:card) { { "type_line" => "Artifact", "oracle_text" => "{T}: Add {C}. You have no maximum hand size." } }

      it { expect(categorizer.category).to eq("ramp") }
    end

    context "Lotus Petal — sacrifice to add mana" do
      let(:card) { { "type_line" => "Artifact", "oracle_text" => "Sacrifice Lotus Petal: Add one mana of any color." } }

      it { expect(categorizer.category).to eq("ramp") }
    end

    context "Darksteel Ingot — taps to add mana" do
      let(:card) { { "type_line" => "Artifact", "oracle_text" => "Indestructible\n{T}: Add one mana of any color." } }

      it { expect(categorizer.category).to eq("ramp") }
    end

    context "Cultivate — land search" do
      let(:card) { { "type_line" => "Sorcery", "oracle_text" => "Search your library for up to two basic land cards..." } }

      it { expect(categorizer.category).to eq("ramp") }
    end

    context "Llanowar Elves — creature that adds mana" do
      let(:card) { { "type_line" => "Creature — Elf Druid", "oracle_text" => "{T}: Add {G}." } }

      it { expect(categorizer.category).to eq("ramp") }
    end

    # --- Draw ---
    context "Opt — impulse draw (look at top card)" do
      let(:card) { { "type_line" => "Instant", "oracle_text" => "Look at the top card of your library. You may put that card on the bottom of your library.\nDraw a card." } }

      it { expect(categorizer.category).to eq("draw") }
    end

    context "Brainstorm — draws three cards" do
      let(:card) { { "type_line" => "Instant", "oracle_text" => "Draw three cards, then put two cards from your hand on top of your library in any order." } }

      it { expect(categorizer.category).to eq("draw") }
    end

    context "Windfall — wheel effect (each player draws)" do
      let(:card) { { "type_line" => "Sorcery", "oracle_text" => "Each player discards their hand, then draws cards equal to the greatest number of cards a player discarded this way." } }

      it { expect(categorizer.category).to eq("draw") }
    end

    context "Mystic Remora — draw a card trigger" do
      let(:card) { { "type_line" => "Enchantment", "oracle_text" => "Whenever an opponent casts a noncreature spell, you may pay {1}. If you don't, draw a card." } }

      it { expect(categorizer.category).to eq("draw") }
    end

    context "Archmage Emeritus — creature with draw trigger" do
      let(:card) { { "type_line" => "Creature — Human Wizard", "oracle_text" => "Magecraft — Whenever you cast or copy an instant or sorcery spell, draw a card." } }

      it { expect(categorizer.category).to eq("draw") }
    end

    # --- Board wipe ---
    context "Cyclonic Rift — has both targeted bounce and return all" do
      let(:card) do
        { "type_line" => "Instant",
          "oracle_text" => "Return target nonland permanent you don't control to its owner's hand.\nOverload {6}{U} (You may cast this spell for its overload cost. If you do, change its text by replacing all instances of \"target\" with \"each\".)\nReturn each nonland permanent you don't control to its owner's hand." }
      end

      it { expect(categorizer.category).to eq("board_wipe") }
    end

    context "Wrath of God — destroy all creatures" do
      let(:card) { { "type_line" => "Sorcery", "oracle_text" => "Destroy all creatures. They can't be regenerated." } }

      it { expect(categorizer.category).to eq("board_wipe") }
    end

    context "Blasphemous Act — deals damage to each creature" do
      let(:card) { { "type_line" => "Sorcery", "oracle_text" => "This spell costs {1} less to cast for each creature on the battlefield.\nBlasmphemous Act deals 13 damage to each creature." } }

      it { expect(categorizer.category).to eq("board_wipe") }
    end

    # --- Removal ---
    context "Counterspell — counters a spell" do
      let(:card) { { "type_line" => "Instant", "oracle_text" => "Counter target spell." } }

      it { expect(categorizer.category).to eq("removal") }
    end

    context "Pongify — destroy target creature" do
      let(:card) { { "type_line" => "Instant", "oracle_text" => "Destroy target creature. Its controller creates a 3/3 green Ape creature token." } }

      it { expect(categorizer.category).to eq("removal") }
    end

    context "Swords to Plowshares — exile target creature" do
      let(:card) { { "type_line" => "Instant", "oracle_text" => "Exile target creature. Its controller gains life equal to its power." } }

      it { expect(categorizer.category).to eq("removal") }
    end

    context "Cyclonic Rift in non-overloaded mode only — treated as board_wipe due to overload text" do
      let(:card) do
        { "type_line" => "Instant",
          "oracle_text" => "Return target nonland permanent you don't control to its owner's hand.\nReturn all nonland permanents you don't control to their owners' hands." }
      end

      it { expect(categorizer.category).to eq("board_wipe") }
    end

    context "Sink into Stupor front face — 'Return target spell or nonland permanent'" do
      let(:card) { { "type_line" => "Instant", "oracle_text" => "Return target spell or nonland permanent an opponent controls to its owner's hand." } }

      it { expect(categorizer.category).to eq("removal") }
    end

    # --- Tutor ---
    context "Demonic Tutor — search library for a card" do
      let(:card) { { "type_line" => "Sorcery", "oracle_text" => "Search your library for a card and put that card into your hand. Then shuffle." } }

      it { expect(categorizer.category).to eq("tutor") }
    end

    context "Enlightened Tutor — search for artifact or enchantment" do
      let(:card) { { "type_line" => "Instant", "oracle_text" => "Search your library for an artifact or enchantment card and reveal that card. Shuffle your library, then put the card on top of it." } }

      it { expect(categorizer.category).to eq("tutor") }
    end

    context "Cultivate — land search is ramp not tutor" do
      let(:card) { { "type_line" => "Sorcery", "oracle_text" => "Search your library for up to two basic land cards, reveal those cards, and put one onto the battlefield tapped and the other into your hand. Then shuffle." } }

      it { expect(categorizer.category).to eq("ramp") }
    end

    # --- Protection ---
    context "Lightning Greaves — grants hexproof" do
      let(:card) { { "type_line" => "Artifact — Equipment", "oracle_text" => "Equipped creature has haste and hexproof. (It can't be the target of spells or abilities your opponents control.)\nEquip {0}" } }

      it { expect(categorizer.category).to eq("protection") }
    end

    context "Swiftfoot Boots — grants hexproof" do
      let(:card) { { "type_line" => "Artifact — Equipment", "oracle_text" => "Equipped creature has haste and hexproof.\nEquip {1}" } }

      it { expect(categorizer.category).to eq("protection") }
    end

    context "Darksteel Plate — grants indestructible" do
      let(:card) { { "type_line" => "Artifact — Equipment", "oracle_text" => "Indestructible\nEquipped creature has indestructible.\nEquip {2}" } }

      it { expect(categorizer.category).to eq("protection") }
    end

    # --- Creature ---
    context "Atraxa — legendary creature with no strong functional text" do
      let(:card) { { "type_line" => "Legendary Creature — Phyrexian Angel Horror", "oracle_text" => "Flying, vigilance, deathtouch, lifelink\nProliferate." } }

      it { expect(categorizer.category).to eq("creature") }
    end

    context "a plain creature" do
      let(:card) { { "type_line" => "Creature — Human Warrior", "oracle_text" => "First strike." } }

      it { expect(categorizer.category).to eq("creature") }
    end

    # --- Type fallbacks ---
    context "a pure instant with no functional oracle text match" do
      let(:card) { { "type_line" => "Instant", "oracle_text" => "Target creature gains flying until end of turn." } }

      it { expect(categorizer.category).to eq("instant") }
    end

    context "a pure sorcery with no functional oracle text match" do
      let(:card) { { "type_line" => "Sorcery", "oracle_text" => "Target creature gets +3/+3 until end of turn." } }

      it { expect(categorizer.category).to eq("sorcery") }
    end

    context "a pure enchantment with no functional oracle text match" do
      let(:card) { { "type_line" => "Enchantment — Aura", "oracle_text" => "Enchant creature. Enchanted creature gets +2/+2." } }

      it { expect(categorizer.category).to eq("enchantment") }
    end

    context "a pure artifact with no functional oracle text match" do
      let(:card) { { "type_line" => "Artifact — Equipment", "oracle_text" => "Equipped creature gets +2/+2.\nEquip {2}" } }

      it { expect(categorizer.category).to eq("artifact") }
    end

    context "a planeswalker" do
      let(:card) { { "type_line" => "Legendary Planeswalker — Jace", "oracle_text" => "+1: Draw a card." } }

      it { expect(categorizer.category).to eq("draw") }
    end

    context "a tribal card" do
      let(:card) { { "type_line" => "Tribal Sorcery — Goblin", "oracle_text" => "Target creature gets +1/+1." } }

      it { expect(categorizer.category).to eq("sorcery") }
    end

    context "when type_line is nil" do
      let(:card) { { "type_line" => nil } }

      it { expect(categorizer.category).to eq("utility") }
    end

    context "when type_line key is missing" do
      let(:card) { {} }

      it { expect(categorizer.category).to eq("utility") }
    end
  end

  describe "#categories" do
    context "MDFC with Instant front face and Land back face" do
      let(:card) do
        {
          "type_line"  => "Instant // Land",
          "card_faces" => [
            { "type_line" => "Instant", "oracle_text" => "Return target nonland permanent to its owner's hand.", "keywords" => [] },
            { "type_line" => "Land",    "oracle_text" => "Soporific Springs enters the battlefield tapped.", "keywords" => [] }
          ]
        }
      end

      it "returns both functional categories" do
        expect(categorizer.categories).to eq([ "removal", "land" ])
      end
    end

    context "split card with removal front and draw back" do
      let(:card) do
        {
          "type_line"  => "Instant // Sorcery",
          "card_faces" => [
            { "type_line" => "Instant", "oracle_text" => "Counter target spell.", "keywords" => [] },
            { "type_line" => "Sorcery", "oracle_text" => "Draw two cards.", "keywords" => [] }
          ]
        }
      end

      it "returns both categories without duplicates" do
        expect(categorizer.categories).to eq([ "removal", "draw" ])
      end
    end

    context "regular card with no card_faces" do
      let(:card) { { "type_line" => "Artifact", "oracle_text" => "{T}: Add {C}{C}." } }

      it "returns a single-element array" do
        expect(categorizer.categories).to eq([ "ramp" ])
      end
    end

    context "MDFC where both faces map to the same category" do
      let(:card) do
        {
          "type_line"  => "Instant // Instant",
          "card_faces" => [
            { "type_line" => "Instant", "oracle_text" => "Counter target spell.", "keywords" => [] },
            { "type_line" => "Instant", "oracle_text" => "Counter target creature spell.", "keywords" => [] }
          ]
        }
      end

      it "returns a single unique category" do
        expect(categorizer.categories).to eq([ "removal" ])
      end
    end
  end
end
