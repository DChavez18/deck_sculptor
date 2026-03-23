class Commander < ApplicationRecord
  has_many :decks, dependent: :destroy

  validates :scryfall_id, presence: true, uniqueness: true
  validates :name, presence: true

  COLOR_MAP = {
    "W" => "White", "U" => "Blue", "B" => "Black",
    "R" => "Red",   "G" => "Green"
  }.freeze

  def color_identity_array
    color_identity.to_s.split(",")
  end

  def color_names
    color_identity_array.map { |c| COLOR_MAP[c] }.compact
  end

  def image_url
    image_uri.presence || "https://cards.scryfall.io/normal/front/placeholder.jpg"
  end

  def self.find_or_create_from_scryfall(card_data)
    find_or_create_by(scryfall_id: card_data["id"]) do |c|
      c.name           = card_data["name"]
      c.type_line      = card_data["type_line"]
      c.oracle_text    = card_data["oracle_text"]
      c.mana_cost      = card_data["mana_cost"]
      c.image_uri      = card_data.dig("image_uris", "normal")
      c.color_identity = card_data["color_identity"]&.join(",")
      c.edhrec_rank    = card_data["edhrec_rank"]
      c.legalities     = card_data["legalities"] || {}
      c.keywords       = card_data["keywords"] || []
      c.raw_data       = card_data
    end
  end

  def multicolored?
    color_identity_array.size > 1
  end

  def colorless?
    color_identity_array.empty?
  end
end
