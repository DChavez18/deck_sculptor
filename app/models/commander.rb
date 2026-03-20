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

  def multicolored?
    color_identity_array.size > 1
  end

  def colorless?
    color_identity_array.empty?
  end
end
