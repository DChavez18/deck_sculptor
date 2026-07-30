require "rails_helper"

RSpec.describe CardCache, type: :model do
  describe "validations" do
    subject { build(:card_cache) }
    it { should validate_presence_of(:scryfall_id) }
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:scryfall_id) }
  end

  describe "#stale?" do
    it "returns false for a fresh cache entry" do
      cache = build(:card_cache, cached_at: 1.hour.ago)
      expect(cache.stale?).to be false
    end

    it "returns true for an entry older than 7 days" do
      cache = build(:card_cache, :stale)
      expect(cache.stale?).to be true
    end
  end

  describe ".fetch" do
    it "returns data for a fresh cached entry" do
      card = create(:card_cache, scryfall_id: "abc-123", cached_at: 1.hour.ago)
      expect(CardCache.fetch("abc-123")).to eq(card.data)
    end

    it "returns nil for a stale entry" do
      create(:card_cache, :stale, scryfall_id: "old-123")
      expect(CardCache.fetch("old-123")).to be_nil
    end

    it "returns nil when no entry exists" do
      expect(CardCache.fetch("nonexistent")).to be_nil
    end
  end

  describe ".fetch_by_name" do
    it "returns data for a fresh entry matching a partial name" do
      card = create(:card_cache, name: "Atraxa, Praetors' Voice", cached_at: 1.hour.ago)
      expect(CardCache.fetch_by_name("Atraxa")).to eq(card.data)
    end

    it "returns nil for a stale entry" do
      create(:card_cache, :stale, name: "Atraxa, Praetors' Voice")
      expect(CardCache.fetch_by_name("Atraxa")).to be_nil
    end

    it "returns nil when no match exists" do
      expect(CardCache.fetch_by_name("Nonexistent")).to be_nil
    end
  end

  describe ".fetch_by_names" do
    it "returns a hash of matching names to data for fresh entries" do
      sol_ring = create(:card_cache, name: "Sol Ring", cached_at: 1.hour.ago)
      command_tower = create(:card_cache, name: "Command Tower", cached_at: 1.hour.ago)

      result = CardCache.fetch_by_names([ "Sol Ring", "Command Tower" ])

      expect(result).to eq(
        "Sol Ring" => sol_ring.data,
        "Command Tower" => command_tower.data
      )
    end

    it "matches case-insensitively" do
      card = create(:card_cache, name: "Sol Ring", cached_at: 1.hour.ago)

      result = CardCache.fetch_by_names([ "sol ring" ])

      expect(result).to eq("sol ring" => card.data)
    end

    it "omits names with no cache entry" do
      create(:card_cache, name: "Sol Ring", cached_at: 1.hour.ago)

      result = CardCache.fetch_by_names([ "Sol Ring", "Nonexistent Card" ])

      expect(result.keys).to eq([ "Sol Ring" ])
    end

    it "omits stale entries" do
      create(:card_cache, :stale, name: "Sol Ring")

      result = CardCache.fetch_by_names([ "Sol Ring" ])

      expect(result).to eq({})
    end

    it "returns an empty hash for an empty list" do
      expect(CardCache.fetch_by_names([])).to eq({})
    end
  end

  describe ".store" do
    it "creates a new cache entry" do
      data = { "name" => "Island", "cmc" => 0 }
      CardCache.store("xyz-999", "Island", data)
      expect(CardCache.find_by(scryfall_id: "xyz-999").data).to eq(data)
    end

    it "updates an existing entry" do
      create(:card_cache, scryfall_id: "xyz-999", name: "Old Name")
      CardCache.store("xyz-999", "New Name", { "name" => "New Name" })
      expect(CardCache.find_by(scryfall_id: "xyz-999").name).to eq("New Name")
    end
  end
end
