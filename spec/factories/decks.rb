FactoryBot.define do
  factory :deck do
    association :commander
    name        { Faker::Lorem.words(number: 3).join(" ").titleize }
    description { Faker::Lorem.sentence }
    archetype   { Deck::ARCHETYPES.sample }
    bracket_level { Faker::Number.between(from: 1, to: 5) }
  end
end
