class SuggestionFeedback < ApplicationRecord
  belongs_to :deck

  FEEDBACK_VALUES = %w[up down].freeze

  validates :scryfall_id, presence: true
  validates :card_name,   presence: true
  validates :feedback,    inclusion: { in: FEEDBACK_VALUES }
  validates :scryfall_id, uniqueness: { scope: :deck_id }
end
