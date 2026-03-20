require "rails_helper"

RSpec.describe Commander, type: :model do
  describe "associations" do
    it { should have_many(:decks).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:commander) }
    it { should validate_presence_of(:scryfall_id) }
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:scryfall_id) }
  end

  describe "#color_identity_array" do
    it "splits the color_identity string into an array" do
      commander = build(:commander, color_identity: "U,B,G")
      expect(commander.color_identity_array).to eq([ "U", "B", "G" ])
    end

    it "returns an empty array when colorless" do
      commander = build(:commander, :colorless)
      expect(commander.color_identity_array).to eq([])
    end
  end

  describe "#color_names" do
    it "maps color letters to full names" do
      commander = build(:commander, color_identity: "W,U")
      expect(commander.color_names).to eq([ "White", "Blue" ])
    end
  end

  describe "#multicolored?" do
    it "returns true when more than one color" do
      commander = build(:commander, :multicolor)
      expect(commander.multicolored?).to be true
    end

    it "returns false for mono-color" do
      commander = build(:commander, color_identity: "U")
      expect(commander.multicolored?).to be false
    end
  end

  describe "#colorless?" do
    it "returns true when no color identity" do
      commander = build(:commander, :colorless)
      expect(commander.colorless?).to be true
    end
  end

  describe "#image_url" do
    it "returns the image_uri when present" do
      commander = build(:commander, image_uri: "https://example.com/card.jpg")
      expect(commander.image_url).to eq("https://example.com/card.jpg")
    end

    it "returns a placeholder when image_uri is blank" do
      commander = build(:commander, image_uri: nil)
      expect(commander.image_url).to include("placeholder")
    end
  end
end
