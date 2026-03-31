require "rails_helper"

RSpec.describe MergeSuggestions, type: :service do
  let(:card_a) { { "id" => "aaa", "name" => "Card A", "color_identity" => [], "oracle_text" => "", "type_line" => "Instant", "cmc" => 2 } }
  let(:card_b) { { "id" => "bbb", "name" => "Card B", "color_identity" => [], "oracle_text" => "", "type_line" => "Sorcery", "cmc" => 3 } }
  let(:card_c) { { "id" => "ccc", "name" => "Card C", "color_identity" => [], "oracle_text" => "", "type_line" => "Creature", "cmc" => 4 } }

  let(:commander_results) do
    [
      { card: card_a, score: 5, reasons: [ "Commander synergy" ] },
      { card: card_b, score: 3, reasons: [ "Curve fill" ] }
    ]
  end

  let(:intent_results) do
    [
      { card: card_a, score: 7, reasons: [ "Intent: Ramp" ], pool: "Ramp" },
      { card: card_c, score: 4, reasons: [ "Intent: Combo" ], pool: "Combo" }
    ]
  end

  subject(:result) { described_class.new(commander_results, intent_results).call }

  it "deduplicates: card_a appears only once" do
    ids = result.map { |s| s[:card]["id"] }
    expect(ids.count("aaa")).to eq(1)
  end

  it "keeps the higher-score entry for card_a (score 7 from intent)" do
    entry = result.find { |s| s[:card]["id"] == "aaa" }
    expect(entry[:score]).to eq(7)
  end

  it "assigns Commander Synergy pool to commander-only results" do
    entry = result.find { |s| s[:card]["id"] == "bbb" }
    expect(entry[:pool]).to eq("Commander Synergy")
  end

  it "includes intent-only cards" do
    ids = result.map { |s| s[:card]["id"] }
    expect(ids).to include("ccc")
  end

  it "sorts by score descending" do
    scores = result.map { |s| s[:score] }
    expect(scores).to eq(scores.sort.reverse)
  end

  it "caps results at 100" do
    many_commander = 60.times.map { |i| { card: { "id" => "c#{i}", "name" => "C#{i}" }, score: i, reasons: [] } }
    many_intent    = 60.times.map { |i| { card: { "id" => "i#{i}", "name" => "I#{i}" }, score: i + 1, reasons: [], pool: "Ramp" } }
    expect(described_class.new(many_commander, many_intent).call.size).to eq(100)
  end
end
