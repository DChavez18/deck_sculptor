class Deck < ApplicationRecord
  belongs_to :commander
  has_many   :deck_cards, dependent: :destroy

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

  def cards_by_category
    deck_cards.group_by(&:category)
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
end
