class Card < ApplicationRecord
  has_many :deck_cards,          dependent: :nullify
  has_many :suggestion_feedbacks, dependent: :destroy

  validates :scryfall_id, presence: true, uniqueness: true
  validates :name,        presence: true

  def self.find_or_create_from_scryfall(card_hash)
    find_or_create_by(scryfall_id: card_hash["id"]) do |c|
      c.name           = card_hash["name"]
      c.type_line      = card_hash["type_line"]
      c.oracle_text    = card_hash["oracle_text"]
      c.image_uri      = card_hash.dig("image_uris", "normal") ||
                         card_hash.dig("card_faces", 0, "image_uris", "normal")
      c.cmc            = card_hash["cmc"]
      c.color_identity = Array(card_hash["color_identity"]).join(",")
    end
  end

  def to_scryfall_hash
    {
      "id"             => scryfall_id,
      "name"           => name,
      "type_line"      => type_line,
      "oracle_text"    => oracle_text,
      "image_uris"     => image_uri ? { "normal" => image_uri } : {},
      "cmc"            => cmc.to_f,
      "color_identity" => color_identity.to_s.split(",").reject(&:empty?)
    }
  end
end
