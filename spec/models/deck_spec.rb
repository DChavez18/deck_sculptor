require "rails_helper"

RSpec.describe Deck, type: :model do
  describe "associations" do
    it { should belong_to(:commander) }
    it { should have_many(:deck_cards).dependent(:destroy) }
    it { should have_many(:suggestion_feedbacks).dependent(:destroy) }
  end

  describe "validations" do
    it { should validate_presence_of(:name) }
    it { should validate_inclusion_of(:archetype).in_array(Deck::ARCHETYPES).allow_nil }
    it { should validate_inclusion_of(:bracket_level).in_array(Deck::BRACKET_LEVELS).allow_nil }
  end

  describe "#card_count" do
    it "returns the total number of cards in the deck" do
      deck = create(:deck)
      create_list(:deck_card, 3, deck: deck, quantity: 1)
      expect(deck.card_count).to eq(3)
    end
  end

  describe "#land_count" do
    it "counts only land cards" do
      deck = create(:deck)
      create_list(:deck_card, 5, :land, deck: deck)
      create_list(:deck_card, 3, :creature, deck: deck)
      expect(deck.land_count).to eq(5)
    end
  end

  describe "#avg_cmc" do
    it "calculates average cmc excluding lands" do
      deck = create(:deck)
      create(:deck_card, deck: deck, cmc: 2.0, category: "creature")
      create(:deck_card, deck: deck, cmc: 4.0, category: "instant")
      create(:deck_card, :land, deck: deck)
      expect(deck.avg_cmc).to eq(3.0)
    end

    it "returns 0.0 when there are no non-land cards" do
      deck = create(:deck)
      create(:deck_card, :land, deck: deck)
      expect(deck.avg_cmc).to eq(0.0)
    end
  end

  describe "#complete?" do
    it "returns true when the deck has exactly 99 cards" do
      deck = create(:deck)
      create_list(:deck_card, 99, deck: deck)
      expect(deck.complete?).to be true
    end

    it "returns false when the deck has fewer than 99 cards" do
      deck = create(:deck)
      create_list(:deck_card, 60, deck: deck)
      expect(deck.complete?).to be false
    end
  end

  describe "#cards_by_category" do
    it "sorts cards alphabetically within each category" do
      deck = create(:deck)
      create(:deck_card, deck: deck, card_name: "Zeal of Ancestors", category: "instant")
      create(:deck_card, deck: deck, card_name: "Aether Vial", category: "instant")
      create(:deck_card, deck: deck, card_name: "Mox Diamond", category: "artifact")

      result = deck.cards_by_category
      expect(result["instant"].map(&:card_name)).to eq(%w[Aether\ Vial Zeal\ of\ Ancestors])
      expect(result["artifact"].map(&:card_name)).to eq([ "Mox Diamond" ])
    end
  end

  describe "#mana_curve" do
    it "groups non-land cards by cmc" do
      deck = create(:deck)
      create(:deck_card, deck: deck, cmc: 1.0, category: "instant")
      create(:deck_card, deck: deck, cmc: 1.0, category: "creature")
      create(:deck_card, deck: deck, cmc: 3.0, category: "sorcery")
      create(:deck_card, :land, deck: deck)
      expect(deck.mana_curve).to eq({ 1 => 2, 3 => 1 })
    end
  end

  describe "#blacklist_card" do
    it "adds the scryfall_id to blacklisted_card_ids" do
      deck = create(:deck)
      deck.blacklist_card("abc-123")
      expect(deck.reload.blacklisted_card_ids).to include("abc-123")
    end

    it "does not add duplicates" do
      deck = create(:deck)
      deck.blacklist_card("abc-123")
      deck.blacklist_card("abc-123")
      expect(deck.reload.blacklisted_card_ids.count("abc-123")).to eq(1)
    end
  end

  describe "#card_blacklisted?" do
    it "returns true for a blacklisted scryfall_id" do
      deck = create(:deck)
      deck.blacklist_card("abc-123")
      expect(deck.card_blacklisted?("abc-123")).to be true
    end

    it "returns false for a non-blacklisted scryfall_id" do
      deck = create(:deck)
      expect(deck.card_blacklisted?("not-blacklisted")).to be false
    end
  end
end
