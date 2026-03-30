FactoryBot.define do
  factory :suggestion_feedback do
    association :deck
    scryfall_id { SecureRandom.uuid }
    card_name   { Faker::Lorem.words(number: 2).join(" ").titleize }
    feedback    { "up" }

    trait :down do
      feedback { "down" }
    end
  end
end
