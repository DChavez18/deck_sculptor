FactoryBot.define do
  factory :card_cache do
    scryfall_id { SecureRandom.uuid }
    name        { Faker::Games::LeagueOfLegends.champion }
    data        { { "name" => name, "cmc" => 3 } }
    cached_at   { Time.current }

    trait :stale do
      cached_at { 8.days.ago }
    end
  end
end
