require "rails_helper"

RSpec.describe ArchetypeDetector do
  let(:commander) { create(:commander, color_identity: "U") }
  let(:deck)      { create(:deck, commander: commander) }

  subject(:detector) { described_class.new(deck) }

  def add_cards(count, overrides = {})
    create_list(:deck_card, count, { deck: deck }.merge(overrides))
  end

  describe "#detect" do
    context "when the deck has fewer than 10 cards" do
      before { add_cards(5) }

      it "returns nil" do
        expect(detector.detect).to be_nil
      end
    end

    context "when the deck has 10 or more cards" do
      context "combo archetype" do
        before do
          add_cards(5, oracle_text: "Search your library for a card (tutor) and put it into your hand.")
          add_cards(3, oracle_text: "Untap all creatures you control. Storm — copy this spell for each spell cast.")
          add_cards(2, oracle_text: "Create an infinite loop with this combo piece.")
        end

        it "detects combo" do
          expect(detector.detect).to eq("combo")
        end
      end

      context "aggro archetype" do
        before do
          add_cards(8, category: "creature", cmc: 2.0, oracle_text: "Haste. This creature attacks each combat if able.")
          add_cards(2, category: "creature", cmc: 1.0, oracle_text: "Put a +1/+1 counter on target creature. Token.")
        end

        it "detects aggro" do
          expect(detector.detect).to eq("aggro")
        end
      end

      context "control archetype" do
        before do
          add_cards(4, category: "instant", oracle_text: "Counter target spell.")
          add_cards(3, category: "instant", oracle_text: "Exile target permanent. Destroy target creature.")
          add_cards(3, category: "instant", oracle_text: "Draw a card. Counter target spell.")
        end

        it "detects control" do
          expect(detector.detect).to eq("control")
        end
      end

      context "stax archetype" do
        before do
          add_cards(5, oracle_text: "Each opponent can't cast more than one spell each turn. Tax each opponent 1 life.")
          add_cards(5, oracle_text: "Prevent all damage. Each opponent can't untap more than two permanents.")
        end

        it "detects stax" do
          expect(detector.detect).to eq("stax")
        end
      end

      context "goodstuff archetype" do
        before do
          add_cards(3, category: "creature", oracle_text: "Flying.")
          add_cards(3, category: "enchantment", oracle_text: "Enchanted permanent gains vigilance.")
          add_cards(2, category: "artifact", oracle_text: "Tap: Add one mana of any color.")
          add_cards(2, category: "land", oracle_text: "")
        end

        it "falls through to goodstuff when no archetype scores high" do
          expect(detector.detect).to eq("goodstuff")
        end
      end
    end
  end
end
