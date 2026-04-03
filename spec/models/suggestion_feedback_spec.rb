require "rails_helper"

RSpec.describe SuggestionFeedback, type: :model do
  describe "associations" do
    it { should belong_to(:deck) }
    it { should belong_to(:card).optional }
  end

  describe "validations" do
    subject { build(:suggestion_feedback) }

    it { should validate_presence_of(:scryfall_id) }
    it { should validate_presence_of(:card_name) }
    it { should validate_inclusion_of(:feedback).in_array(SuggestionFeedback::FEEDBACK_VALUES) }

    it "enforces uniqueness of scryfall_id scoped to deck" do
      existing = create(:suggestion_feedback)
      duplicate = build(:suggestion_feedback, deck: existing.deck, scryfall_id: existing.scryfall_id)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:scryfall_id]).to be_present
    end

    it "allows the same scryfall_id for a different deck" do
      existing   = create(:suggestion_feedback)
      other_deck = create(:deck)
      other      = build(:suggestion_feedback, deck: other_deck, scryfall_id: existing.scryfall_id)
      expect(other).to be_valid
    end
  end
end
