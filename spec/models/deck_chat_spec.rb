require "rails_helper"

RSpec.describe DeckChat, type: :model do
  describe "associations" do
    it { should belong_to(:deck) }
  end

  describe "validations" do
    it { should validate_inclusion_of(:role).in_array(%w[user assistant]) }
    it { should validate_presence_of(:content) }
  end

  describe "factory" do
    it "creates a valid user chat" do
      chat = build(:deck_chat)
      expect(chat).to be_valid
    end

    it "creates a valid assistant chat" do
      chat = build(:deck_chat, :assistant)
      expect(chat).to be_valid
    end

    it "is invalid without a role" do
      chat = build(:deck_chat, role: nil)
      expect(chat).not_to be_valid
    end

    it "is invalid with an unrecognized role" do
      chat = build(:deck_chat, role: "system")
      expect(chat).not_to be_valid
    end

    it "is invalid without content" do
      chat = build(:deck_chat, content: nil)
      expect(chat).not_to be_valid
    end
  end
end
