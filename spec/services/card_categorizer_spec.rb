require "rails_helper"

RSpec.describe CardCategorizer do
  subject(:categorizer) { described_class.new(card) }

  describe "#category" do
    context "when type_line is a Land" do
      let(:card) { { "type_line" => "Basic Land — Island" } }

      it { expect(categorizer.category).to eq("land") }
    end

    context "when type_line is a Creature" do
      let(:card) { { "type_line" => "Creature — Human Wizard" } }

      it { expect(categorizer.category).to eq("creature") }
    end

    context "when type_line is a Legendary Creature" do
      let(:card) { { "type_line" => "Legendary Creature — Dragon" } }

      it { expect(categorizer.category).to eq("creature") }
    end

    context "when type_line is an Instant" do
      let(:card) { { "type_line" => "Instant" } }

      it { expect(categorizer.category).to eq("instant") }
    end

    context "when type_line is a Sorcery" do
      let(:card) { { "type_line" => "Sorcery" } }

      it { expect(categorizer.category).to eq("sorcery") }
    end

    context "when type_line is an Enchantment" do
      let(:card) { { "type_line" => "Enchantment — Aura" } }

      it { expect(categorizer.category).to eq("enchantment") }
    end

    context "when type_line is an Artifact" do
      let(:card) { { "type_line" => "Artifact — Equipment" } }

      it { expect(categorizer.category).to eq("artifact") }
    end

    context "when type_line is a Planeswalker" do
      let(:card) { { "type_line" => "Legendary Planeswalker — Jace" } }

      it { expect(categorizer.category).to eq("planeswalker") }
    end

    context "when type_line is something unknown" do
      let(:card) { { "type_line" => "Tribal Sorcery — Goblin" } }

      it { expect(categorizer.category).to eq("utility") }
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
end
