class CardCache < ApplicationRecord
  CACHE_TTL = 7.days

  validates :scryfall_id, presence: true, uniqueness: true
  validates :name,        presence: true

  def self.fetch(scryfall_id)
    record = find_by(scryfall_id: scryfall_id)
    return record.data if record && !record.stale?
    nil
  end

  def self.fetch_by_name(name)
    record = find_by("name ILIKE ?", "%#{name}%")
    return record.data if record && !record.stale?
    nil
  end

  def self.store(scryfall_id, name, data)
    record = find_or_initialize_by(scryfall_id: scryfall_id)
    record.update!(name: name, data: data, cached_at: Time.current)
    data
  end

  def stale?
    cached_at < CACHE_TTL.ago
  end
end
