require "rails_helper"

RSpec.describe CurveAdvisor do
  let(:commander) { create(:commander) }
  let(:deck)      { create(:deck, commander: commander) }
  subject(:advisor) { described_class.new(deck) }

  describe "#recommendations" do
    it "returns an empty array when the deck has no cards" do
      expect(advisor.recommendations).to eq([])
    end

    context "when the low end of the curve is light (fewer than 8 cards at CMC 1-2)" do
      before do
        create(:deck_card, deck: deck, cmc: 1.0, quantity: 2, category: "creature")
        create(:deck_card, deck: deck, cmc: 2.0, quantity: 3, category: "creature")
        create(:deck_card, deck: deck, cmc: 4.0, quantity: 10, category: "creature")
      end

      it "recommends adding early plays" do
        expect(advisor.recommendations).to include(
          a_string_matching(/light on early plays/)
        )
      end
    end

    context "when the low end of the curve has 8 or more cards at CMC 1-2" do
      before do
        create(:deck_card, deck: deck, cmc: 1.0, quantity: 4, category: "instant")
        create(:deck_card, deck: deck, cmc: 2.0, quantity: 5, category: "instant")
      end

      it "does not recommend adding early plays" do
        expect(advisor.recommendations).not_to include(a_string_matching(/light on early plays/))
      end
    end

    context "when more than 15 cards are at CMC 5+" do
      before do
        create(:deck_card, deck: deck, cmc: 5.0, quantity: 10, category: "creature")
        create(:deck_card, deck: deck, cmc: 6.0, quantity: 6, category: "creature")
      end

      it "recommends cutting high CMC cards" do
        expect(advisor.recommendations).to include(
          a_string_matching(/curve runs heavy/)
        )
      end
    end

    context "when 15 or fewer cards are at CMC 5+" do
      before do
        create(:deck_card, deck: deck, cmc: 5.0, quantity: 5, category: "creature")
        create(:deck_card, deck: deck, cmc: 6.0, quantity: 4, category: "creature")
      end

      it "does not flag the high end" do
        expect(advisor.recommendations).not_to include(a_string_matching(/curve runs heavy/))
      end
    end

    context "when average CMC is above 3.5" do
      before do
        create(:deck_card, deck: deck, cmc: 5.0, quantity: 20, category: "creature")
        create(:deck_card, deck: deck, cmc: 4.0, quantity: 10, category: "creature")
      end

      it "recommends lowering average CMC" do
        expect(advisor.recommendations).to include(
          a_string_matching(/average CMC is high/)
        )
      end
    end

    context "when average CMC is at or below 3.5" do
      before do
        create(:deck_card, deck: deck, cmc: 1.0, quantity: 10, category: "instant")
        create(:deck_card, deck: deck, cmc: 3.0, quantity: 10, category: "creature")
      end

      it "does not flag average CMC as high" do
        expect(advisor.recommendations).not_to include(a_string_matching(/average CMC is high/))
      end
    end

    context "when average CMC is below 2.5 and archetype is not aggro" do
      before do
        allow(ArchetypeDetector).to receive(:new).and_return(
          instance_double(ArchetypeDetector, detect: "control")
        )
        create(:deck_card, deck: deck, cmc: 1.0, quantity: 20, category: "instant")
        create(:deck_card, deck: deck, cmc: 2.0, quantity: 5, category: "instant")
      end

      it "notes the very low curve" do
        expect(advisor.recommendations).to include(
          a_string_matching(/curve is very low/)
        )
      end
    end

    context "when average CMC is below 2.5 and archetype is aggro" do
      before do
        allow(ArchetypeDetector).to receive(:new).and_return(
          instance_double(ArchetypeDetector, detect: "aggro")
        )
        create(:deck_card, deck: deck, cmc: 1.0, quantity: 20, category: "creature")
        create(:deck_card, deck: deck, cmc: 2.0, quantity: 5, category: "creature")
      end

      it "does not flag the low curve for aggro decks" do
        expect(advisor.recommendations).not_to include(a_string_matching(/curve is very low/))
      end
    end

    it "excludes lands from average CMC calculation" do
      create(:deck_card, deck: deck, cmc: 0.0, quantity: 36, category: "land")
      create(:deck_card, deck: deck, cmc: 4.0, quantity: 20, category: "creature")
      avg = deck.deck_cards.reject { |dc| dc.category == "land" }.sum { |dc| dc.cmc.to_f * dc.quantity } /
            deck.deck_cards.reject { |dc| dc.category == "land" }.sum(&:quantity).to_f
      expect(avg).to be > 3.5
      expect(advisor.recommendations).to include(a_string_matching(/average CMC is high/))
    end
  end
end
