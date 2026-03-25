require "rails_helper"

RSpec.describe StrategyAnalyzer do
  let(:commander) { create(:commander, name: "Alela, Artful Provocateur", color_identity: "W,U,B") }
  let(:deck)      { create(:deck, commander: commander) }

  subject(:analyzer) { described_class.new(deck) }

  before do
    create_list(:deck_card, 8, deck: deck, category: "instant",
                oracle_text: "Counter target spell. Draw a card.")
    create_list(:deck_card, 4, deck: deck, category: "instant",
                oracle_text: "Exile target permanent. Destroy target creature.")
  end

  describe "#report" do
    it "returns a hash with the expected keys" do
      result = analyzer.report
      expect(result).to include(:detected_archetype, :color_gaps, :strategy_summary, :key_themes)
    end

    it "includes a detected_archetype string" do
      expect(analyzer.report[:detected_archetype]).to be_a(String).or be_nil
    end

    it "includes color_gaps with the expected sub-keys" do
      gaps = analyzer.report[:color_gaps]
      expect(gaps).to include(:missing_colors, :off_color_cards, :color_distribution)
    end

    it "includes a non-empty strategy_summary string" do
      expect(analyzer.report[:strategy_summary]).to be_a(String)
      expect(analyzer.report[:strategy_summary]).not_to be_empty
    end

    it "includes key_themes as an array of up to 5 strings" do
      themes = analyzer.report[:key_themes]
      expect(themes).to be_an(Array)
      expect(themes.length).to be <= 5
      expect(themes).to all(be_a(String))
    end

    it "includes the commander name in the strategy_summary" do
      expect(analyzer.report[:strategy_summary]).to include("Alela, Artful Provocateur")
    end

    it "detects control for this deck composition" do
      expect(analyzer.report[:detected_archetype]).to eq("control")
    end
  end
end
