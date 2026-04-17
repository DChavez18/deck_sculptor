require "rails_helper"

RSpec.describe RatioAnalyzer do
  let(:commander) { create(:commander) }
  let(:deck)      { create(:deck, commander: commander) }
  subject(:analyzer) { described_class.new(deck) }

  describe "#report" do
    it "returns a hash with the five standard buckets" do
      report = analyzer.report
      expect(report.keys).to match_array(%i[ramp draw removal land creature])
    end

    it "includes actual, target, and cut_suggestions for each bucket" do
      report = analyzer.report
      report.each_value do |data|
        expect(data).to include(:actual, :target, :cut_suggestions)
      end
    end

    it "returns zero actuals when deck is empty" do
      report = analyzer.report
      report.each_value { |data| expect(data[:actual]).to eq(0) }
    end

    describe "targets" do
      it "sets ramp target to 10"     do expect(analyzer.report[:ramp][:target]).to eq(10) end
      it "sets draw target to 10"     do expect(analyzer.report[:draw][:target]).to eq(10) end
      it "sets removal target to 8"   do expect(analyzer.report[:removal][:target]).to eq(8) end
      it "sets land target to 36"     do expect(analyzer.report[:land][:target]).to eq(36) end
      it "sets creature target to 25" do expect(analyzer.report[:creature][:target]).to eq(25) end
    end

    describe "actuals" do
      before do
        create(:deck_card, deck: deck, category: "ramp",     quantity: 5)
        create(:deck_card, deck: deck, category: "draw",     quantity: 8)
        create(:deck_card, deck: deck, category: "removal",  quantity: 3)
        create(:deck_card, deck: deck, category: "land",     quantity: 36)
        create(:deck_card, deck: deck, category: "creature", quantity: 10)
      end

      it "counts ramp cards correctly"     do expect(analyzer.report[:ramp][:actual]).to eq(5) end
      it "counts draw cards correctly"     do expect(analyzer.report[:draw][:actual]).to eq(8) end
      it "counts removal cards correctly"  do expect(analyzer.report[:removal][:actual]).to eq(3) end
      it "counts land cards correctly"     do expect(analyzer.report[:land][:actual]).to eq(36) end
      it "counts creature cards correctly" do expect(analyzer.report[:creature][:actual]).to eq(10) end

      it "ignores categories not in the five buckets" do
        create(:deck_card, deck: deck, category: "enchantment", quantity: 5)
        report = analyzer.report
        total = report.values.sum { |d| d[:actual] }
        expect(total).to eq(62)
      end
    end

    describe "quantity summing" do
      it "sums quantity across multiple rows in the same category" do
        create(:deck_card, deck: deck, card_name: "Island", category: "land", quantity: 26)
        create(:deck_card, deck: deck, card_name: "Swamp",  category: "land", quantity: 8)
        expect(analyzer.report[:land][:actual]).to eq(34)
      end
    end

    describe "cut_suggestions" do
      context "when a category is under target" do
        before { create(:deck_card, deck: deck, category: "creature", quantity: 5, cmc: 3.0) }

        it "returns no cut suggestions" do
          expect(analyzer.report[:creature][:cut_suggestions]).to be_empty
        end
      end

      context "when a category is at target" do
        before { create(:deck_card, deck: deck, category: "creature", quantity: 25, cmc: 3.0) }

        it "returns no cut suggestions" do
          expect(analyzer.report[:creature][:cut_suggestions]).to be_empty
        end
      end

      context "when a category is over target" do
        before do
          create(:deck_card, deck: deck, card_name: "Cheap Creature",     category: "creature", quantity: 10, cmc: 1.0)
          create(:deck_card, deck: deck, card_name: "Mid Creature",       category: "creature", quantity: 10, cmc: 3.0)
          create(:deck_card, deck: deck, card_name: "Expensive Creature", category: "creature", quantity: 10, cmc: 6.0)
        end

        it "returns up to 3 cut suggestions" do
          cuts = analyzer.report[:creature][:cut_suggestions]
          expect(cuts.size).to be <= 3
        end

        it "suggests highest CMC cards first" do
          cuts = analyzer.report[:creature][:cut_suggestions]
          expect(cuts.first[:cmc]).to eq(6)
        end

        it "includes card name and cmc in each suggestion" do
          cuts = analyzer.report[:creature][:cut_suggestions]
          cuts.each do |cut|
            expect(cut).to include(:name, :cmc)
          end
        end
      end
    end
  end
end
