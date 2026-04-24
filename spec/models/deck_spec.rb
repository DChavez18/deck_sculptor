require "rails_helper"

RSpec.describe Deck, type: :model do
  describe "associations" do
    it { should belong_to(:commander) }
    it { should belong_to(:user).optional }
    it { should have_many(:deck_cards).dependent(:destroy) }
    it { should have_many(:suggestion_feedbacks).dependent(:destroy) }
  end

  describe "validations" do
    it { should validate_presence_of(:name) }
    it { should validate_inclusion_of(:archetype).in_array(Deck::ARCHETYPES).allow_nil }
    it { should validate_inclusion_of(:bracket_level).in_array(Deck::BRACKET_LEVELS).allow_nil }

    it "is valid with a user_id and no anonymous_session_token" do
      expect(build(:deck, :owned_by_user)).to be_valid
    end

    it "is valid with anonymous_session_token and no user_id" do
      expect(build(:deck)).to be_valid
    end

    it "is invalid with neither user_id nor anonymous_session_token" do
      deck = build(:deck, anonymous_session_token: nil, user: nil)
      expect(deck).not_to be_valid
      expect(deck.errors[:base]).to include("must belong to a user or have a session token")
    end
  end

  describe ".owned_by" do
    let(:user) { create(:user) }
    let!(:user_deck) { create(:deck, :owned_by_user, user: user) }
    let!(:token_deck) { create(:deck, anonymous_session_token: "abc123") }
    let!(:other_deck) { create(:deck, anonymous_session_token: "other") }

    it "returns decks scoped to user when passed a User" do
      expect(Deck.owned_by(user)).to contain_exactly(user_deck)
    end

    it "returns decks scoped to token when passed a string" do
      expect(Deck.owned_by("abc123")).to contain_exactly(token_deck)
    end
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

  describe "#cards_by_type" do
    it "groups cards by type_line" do
      deck = create(:deck)
      create(:deck_card, deck: deck, card_name: "Lightning Bolt", category: "instant", type_line: "Instant")
      create(:deck_card, deck: deck, card_name: "Birds of Paradise", category: "creature", type_line: "Creature — Bird")
      create(:deck_card, deck: deck, card_name: "Forest", category: "land", type_line: "Basic Land — Forest")

      result = deck.cards_by_type
      expect(result.keys).to eq(%w[creature instant land])
    end

    it "sorts creatures before instants before lands" do
      deck = create(:deck)
      create(:deck_card, deck: deck, card_name: "Llanowar Elves", category: "ramp", type_line: "Creature — Elf")
      create(:deck_card, deck: deck, card_name: "Counterspell", category: "removal", type_line: "Instant")
      create(:deck_card, deck: deck, card_name: "Swamp", category: "land", type_line: "Basic Land — Swamp")

      types = deck.cards_by_type.keys
      expect(types.index("creature")).to be < types.index("instant")
      expect(types.index("instant")).to be < types.index("land")
    end

    it "sorts cards alphabetically within each type" do
      deck = create(:deck)
      create(:deck_card, deck: deck, card_name: "Zap", category: "instant", type_line: "Instant")
      create(:deck_card, deck: deck, card_name: "Arcane Denial", category: "instant", type_line: "Instant")

      result = deck.cards_by_type
      expect(result["instant"].map(&:card_name)).to eq(%w[Arcane\ Denial Zap])
    end

    it "assigns unknown type_lines to other" do
      deck = create(:deck)
      create(:deck_card, deck: deck, card_name: "Weird Card", category: "utility", type_line: "Tribal")

      result = deck.cards_by_type
      expect(result.keys).to include("other")
    end

    it "buckets Enchantment Land type_line as land not enchantment" do
      deck = create(:deck)
      create(:deck_card, deck: deck, card_name: "Urza's Saga", category: "enchantment", type_line: "Enchantment Land — Urza's")

      result = deck.cards_by_type
      expect(result.keys).to include("land")
      expect(result.keys).not_to include("enchantment")
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
