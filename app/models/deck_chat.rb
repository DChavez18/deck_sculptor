class DeckChat < ApplicationRecord
  belongs_to :deck

  validates :role,    inclusion: { in: %w[user assistant] }
  validates :content, presence: true
end
