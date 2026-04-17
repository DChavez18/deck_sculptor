require "rails_helper"

RSpec.describe DecklistParser do
  subject(:parser) { described_class.new(text) }

  describe "#parse" do
    context "standard format (quantity name)" do
      let(:text) { "1 Sol Ring\n2 Forest" }

      it "parses both lines" do
        expect(parser.parse).to eq([
          { name: "Sol Ring", quantity: 1 },
          { name: "Forest",   quantity: 2 }
        ])
      end
    end

    context "1x prefix format" do
      let(:text) { "1x Arcane Signet\n4x Mountain" }

      it "parses both lines" do
        expect(parser.parse).to eq([
          { name: "Arcane Signet", quantity: 1 },
          { name: "Mountain",      quantity: 4 }
        ])
      end
    end

    context "set code and collector number stripping" do
      let(:text) { "1 Sol Ring (CMR) 281\n1 Command Tower (ELD) 333" }

      it "strips set code and collector number" do
        result = parser.parse
        expect(result.map { |e| e[:name] }).to eq([ "Sol Ring", "Command Tower" ])
      end
    end

    context "no quantity (bare card name)" do
      let(:text) { "Sol Ring" }

      it "defaults quantity to 1" do
        expect(parser.parse).to eq([ { name: "Sol Ring", quantity: 1 } ])
      end
    end

    context "ignores comment lines starting with //" do
      let(:text) { "// This is a comment\n1 Sol Ring" }

      it "skips the comment" do
        expect(parser.parse).to eq([ { name: "Sol Ring", quantity: 1 } ])
      end
    end

    context "ignores comment lines starting with #" do
      let(:text) { "# sideboard\n1 Sol Ring" }

      it "skips the comment" do
        expect(parser.parse).to eq([ { name: "Sol Ring", quantity: 1 } ])
      end
    end

    context "ignores blank lines" do
      let(:text) { "1 Sol Ring\n\n1 Forest" }

      it "skips blank lines" do
        expect(parser.parse).to eq([
          { name: "Sol Ring", quantity: 1 },
          { name: "Forest",   quantity: 1 }
        ])
      end
    end

    context "section header skipping" do
      let(:text) { "Commander\n1 Atraxa\nDeck\n1 Sol Ring\nSideboard\n1 Opt\nMaybeboard\n1 Ponder" }

      it "imports only Deck section cards, skipping Commander/Sideboard/Maybeboard" do
        result = parser.parse
        expect(result.map { |e| e[:name] }).to eq([ "Sol Ring" ])
      end
    end

    context "(PLST) set code with dash collector number" do
      let(:text) { "1 Fabricate (PLST) M10-52" }

      it "strips set code and collector number" do
        expect(parser.parse).to eq([ { name: "Fabricate", quantity: 1 } ])
      end
    end

    context "set code only, no collector number" do
      let(:text) { "1 Brainstorm (CMD)" }

      it "strips the set code" do
        expect(parser.parse).to eq([ { name: "Brainstorm", quantity: 1 } ])
      end
    end

    context "cards under Commander section are skipped" do
      let(:text) { "Commander\n1 Atraxa, Praetors' Voice\nDeck\n1 Sol Ring" }

      it "skips the commander card" do
        result = parser.parse
        expect(result.map { |e| e[:name] }).to eq([ "Sol Ring" ])
      end
    end

    context "cards under Sideboard section are skipped" do
      let(:text) { "Deck\n1 Sol Ring\nSideboard\n1 Opt" }

      it "skips sideboard cards" do
        result = parser.parse
        expect(result.map { |e| e[:name] }).to eq([ "Sol Ring" ])
      end
    end

    context "cards with no section header are imported" do
      let(:text) { "1 Sol Ring\n1 Arcane Signet" }

      it "imports all cards" do
        result = parser.parse
        expect(result.map { |e| e[:name] }).to eq([ "Sol Ring", "Arcane Signet" ])
      end
    end

    context "empty input" do
      let(:text) { "" }

      it "returns an empty array" do
        expect(parser.parse).to be_empty
      end
    end

    context "nil input" do
      subject(:parser) { described_class.new(nil) }

      it "returns an empty array without raising" do
        expect(parser.parse).to be_empty
      end
    end
  end
end
