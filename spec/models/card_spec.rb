require "rails_helper"

RSpec.describe Card, type: :model do
  describe "associations" do
    it { should have_many(:deck_cards).dependent(:nullify) }
    it { should have_many(:suggestion_feedbacks).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:card) }

    it { should validate_presence_of(:scryfall_id) }
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:scryfall_id) }
  end

  describe ".find_or_create_from_scryfall" do
    let(:card_hash) do
      {
        "id"             => "abc-123",
        "name"           => "Sol Ring",
        "type_line"      => "Artifact",
        "oracle_text"    => "{T}: Add {C}{C}.",
        "image_uris"     => { "normal" => "https://cards.scryfall.io/normal/front/abc.jpg" },
        "cmc"            => 1.0,
        "color_identity" => []
      }
    end

    it "creates a Card record from a Scryfall card hash" do
      card = Card.find_or_create_from_scryfall(card_hash)

      expect(card).to be_persisted
      expect(card.scryfall_id).to eq("abc-123")
      expect(card.name).to eq("Sol Ring")
      expect(card.type_line).to eq("Artifact")
      expect(card.oracle_text).to eq("{T}: Add {C}{C}.")
      expect(card.image_uri).to eq("https://cards.scryfall.io/normal/front/abc.jpg")
      expect(card.cmc).to eq(1.0)
      expect(card.color_identity).to eq("")
    end

    it "is idempotent — calling twice returns the same record" do
      first  = Card.find_or_create_from_scryfall(card_hash)
      second = Card.find_or_create_from_scryfall(card_hash)

      expect(second.id).to eq(first.id)
      expect(Card.where(scryfall_id: "abc-123").count).to eq(1)
    end

    it "falls back to card_faces image_uris for double-faced cards" do
      dfc_hash = card_hash.except("image_uris").merge(
        "card_faces" => [
          { "image_uris" => { "normal" => "https://cards.scryfall.io/normal/front/dfc.jpg" } }
        ]
      )

      card = Card.find_or_create_from_scryfall(dfc_hash)

      expect(card.image_uri).to eq("https://cards.scryfall.io/normal/front/dfc.jpg")
    end

    it "stores color_identity as a comma-separated string" do
      colored_hash = card_hash.merge("color_identity" => [ "B", "R" ])

      card = Card.find_or_create_from_scryfall(colored_hash)

      expect(card.color_identity).to eq("B,R")
    end
  end

  describe "#to_scryfall_hash" do
    let(:card) { build(:card, scryfall_id: "xyz-456", color_identity: "U,G") }

    it "returns a hash compatible with the Scryfall card format" do
      hash = card.to_scryfall_hash

      expect(hash["id"]).to eq("xyz-456")
      expect(hash["name"]).to eq(card.name)
      expect(hash["type_line"]).to eq(card.type_line)
      expect(hash["oracle_text"]).to eq(card.oracle_text)
      expect(hash["cmc"]).to eq(card.cmc.to_f)
      expect(hash["color_identity"]).to eq([ "U", "G" ])
      expect(hash["image_uris"]).to eq({ "normal" => card.image_uri })
    end

    it "returns empty image_uris when image_uri is blank" do
      card.image_uri = nil

      expect(card.to_scryfall_hash["image_uris"]).to eq({})
    end

    it "returns an empty color_identity array when color_identity is blank" do
      card.color_identity = ""

      expect(card.to_scryfall_hash["color_identity"]).to eq([])
    end
  end
end
