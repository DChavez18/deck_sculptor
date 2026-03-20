require "rails_helper"

RSpec.describe DeckCard, type: :model do
  describe "associations" do
    it { should belong_to(:deck) }
  end

  describe "validations" do
    it { should validate_presence_of(:card_name) }
    it { should validate_presence_of(:scryfall_id) }
    it { should validate_numericality_of(:quantity).is_greater_than(0) }
  end

  describe "#land?" do
    it "returns true for land category" do
      card = build(:deck_card, :land)
      expect(card.land?).to be true
    end

    it "returns true when type_line includes Land" do
      card = build(:deck_card, category: "utility", type_line: "Basic Land — Forest")
      expect(card.land?).to be true
    end

    it "returns false for non-land cards" do
      card = build(:deck_card, :creature)
      expect(card.land?).to be false
    end
  end

  describe "#color_identity_array" do
    it "splits a comma-separated string" do
      card = build(:deck_card, color_identity: "U,B")
      expect(card.color_identity_array).to eq(["U", "B"])
    end
  end
end
