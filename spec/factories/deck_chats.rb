FactoryBot.define do
  factory :deck_chat do
    association :deck
    role    { "user" }
    content { Faker::Lorem.sentence }

    trait :assistant do
      role { "assistant" }
    end
  end
end
