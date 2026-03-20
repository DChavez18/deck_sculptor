class DeckCard < ApplicationRecord
  belongs_to :deck

  CATEGORIES = %w[
    creature enchantment artifact instant sorcery
    planeswalker land ramp draw removal protection combo utility
  ].freeze

  validates :card_name,   presence: true
  validates :scryfall_id, presence: true
  validates :quantity,    numericality: { greater_than: 0, less_than: 4 }
  validates :category,    inclusion: { in: CATEGORIES }, allow_nil: true

  def color_identity_array
    color_identity.to_s.split(",")
  end

  def land?
    category == "land" || type_line.to_s.include?("Land")
  end
end
