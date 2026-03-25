class DeckCard < ApplicationRecord
  belongs_to :deck

  CATEGORIES = %w[
    creature enchantment artifact instant sorcery
    planeswalker land ramp draw removal protection combo utility
  ].freeze

  BASIC_LANDS = %w[Plains Island Swamp Mountain Forest Wastes].freeze

  validates :card_name,   presence: true
  validates :scryfall_id, presence: true
  validates :quantity,    numericality: { greater_than: 0 }
  validates :category,    inclusion: { in: CATEGORIES }, allow_nil: true

  def color_identity_array
    color_identity.to_s.split(",")
  end

  def land?
    category == "land" || type_line.to_s.include?("Land")
  end

  def basic_land?
    BASIC_LANDS.include?(card_name)
  end
end
