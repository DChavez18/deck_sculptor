require "rails_helper"

RSpec.describe ColorGapAnalyzer do
  let(:commander) { create(:commander, color_identity: "W,U,B") }
  let(:deck)      { create(:deck, commander: commander) }

  subject(:analyzer) { described_class.new(deck) }

  describe "#analyze" do
    context "with a full spread of commander colors represented" do
      before do
        create(:deck_card, deck: deck, color_identity: "W",   card_name: "White Card")
        create(:deck_card, deck: deck, color_identity: "U",   card_name: "Blue Card")
        create(:deck_card, deck: deck, color_identity: "B",   card_name: "Black Card")
        create(:deck_card, deck: deck, color_identity: "W,U", card_name: "Azorius Card")
      end

      it "reports no missing colors" do
        expect(analyzer.analyze[:missing_colors]).to be_empty
      end

      it "reports no off-color cards" do
        expect(analyzer.analyze[:off_color_cards]).to be_empty
      end

      it "returns a color distribution hash" do
        distribution = analyzer.analyze[:color_distribution]
        expect(distribution["W"]).to be >= 2
        expect(distribution["U"]).to be >= 2
        expect(distribution["B"]).to be >= 1
      end
    end

    context "when some commander colors are missing from the 99" do
      before do
        create(:deck_card, deck: deck, color_identity: "W", card_name: "White Card")
        # No blue or black cards added
      end

      it "lists the missing colors" do
        missing = analyzer.analyze[:missing_colors]
        expect(missing).to include("U", "B")
        expect(missing).not_to include("W")
      end
    end

    context "when the deck contains off-color cards" do
      before do
        create(:deck_card, deck: deck, color_identity: "R", card_name: "Red Card")
        create(:deck_card, deck: deck, color_identity: "G", card_name: "Green Card")
        create(:deck_card, deck: deck, color_identity: "U", card_name: "Blue Card")
      end

      it "flags off-color cards" do
        off_color = analyzer.analyze[:off_color_cards]
        names = off_color.map(&:card_name)
        expect(names).to include("Red Card", "Green Card")
        expect(names).not_to include("Blue Card")
      end
    end

    context "with colorless cards" do
      before do
        create(:deck_card, deck: deck, color_identity: "", card_name: "Sol Ring")
        create(:deck_card, deck: deck, color_identity: "W", card_name: "White Card")
      end

      it "does not flag colorless cards as off-color" do
        off_color = analyzer.analyze[:off_color_cards]
        names = off_color.map(&:card_name)
        expect(names).not_to include("Sol Ring")
      end
    end

    context "color_distribution" do
      before do
        create(:deck_card, deck: deck, color_identity: "W",   quantity: 3, card_name: "White A")
        create(:deck_card, deck: deck, color_identity: "U",   quantity: 2, card_name: "Blue A")
        create(:deck_card, deck: deck, color_identity: "W,U", quantity: 1, card_name: "Azorius A")
      end

      it "counts each color across all cards by quantity" do
        distribution = analyzer.analyze[:color_distribution]
        expect(distribution["W"]).to eq(4)  # 3 + 1
        expect(distribution["U"]).to eq(3)  # 2 + 1
      end
    end
  end
end
