class Deck < ApplicationRecord
  belongs_to :commander
  has_many   :deck_cards,          dependent: :destroy
  has_many   :suggestion_feedbacks, dependent: :destroy
  has_many   :deck_chats,           dependent: :destroy

  ARCHETYPES     = %w[aggro combo control stax midrange goodstuff].freeze
  BRACKET_LEVELS = (1..5).to_a.freeze
  BUDGETS        = %w[casual optimized competitive].freeze

  validates :name, presence: true
  validates :archetype,      inclusion: { in: ARCHETYPES },     allow_nil: true
  validates :bracket_level,  inclusion: { in: BRACKET_LEVELS }, allow_nil: true
  validates :budget,         inclusion: { in: BUDGETS },        allow_nil: true

  def card_count
    deck_cards.sum(:quantity)
  end

  def land_count
    deck_cards.where(category: "land").sum(:quantity)
  end

  def avg_cmc
    non_lands = deck_cards.where.not(category: "land")
    return 0.0 if non_lands.empty?
    (non_lands.sum(:cmc) / non_lands.count.to_f).round(2)
  end

  TYPE_LABELS = {
    "creature"     => "Creature",
    "instant"      => "Instant",
    "sorcery"      => "Sorcery",
    "artifact"     => "Artifact",
    "enchantment"  => "Enchantment",
    "planeswalker" => "Planeswalker",
    "land"         => "Land",
    "other"        => "Other"
  }.freeze

  def cards_by_category
    deck_cards.sort_by(&:card_name).group_by(&:category)
  end

  DISPLAY_ORDER = %w[creature instant sorcery artifact enchantment planeswalker land other].freeze

  def cards_by_type
    type_priority = %w[land creature instant sorcery artifact enchantment planeswalker]
    deck_cards.sort_by(&:card_name).group_by do |dc|
      type_line = dc.type_line.to_s.downcase
      type_priority.find { |t| type_line.include?(t) } || "other"
    end.sort_by { |type, _| DISPLAY_ORDER.index(type) || 999 }.to_h
  end

  def mana_curve
    deck_cards
      .where.not(category: "land")
      .group(:cmc)
      .sum(:quantity)
      .transform_keys(&:to_i)
      .sort
      .to_h
  end

  def complete?
    card_count == 99
  end

  def blacklist_card(scryfall_id)
    return if blacklisted_card_ids.include?(scryfall_id)
    update!(blacklisted_card_ids: blacklisted_card_ids + [ scryfall_id ])
  end

  def card_blacklisted?(scryfall_id)
    blacklisted_card_ids.include?(scryfall_id)
  end
end
