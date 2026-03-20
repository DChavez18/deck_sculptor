FactoryBot.define do
  factory :commander do
    scryfall_id    { SecureRandom.uuid }
    name           { Faker::Games::LeagueOfLegends.champion }
    color_identity { "U" }
    type_line      { "Legendary Creature — Human Wizard" }
    oracle_text    { Faker::Lorem.paragraph }
    mana_cost      { "{2}{U}{U}" }
    image_uri      { "https://cards.scryfall.io/normal/front/placeholder.jpg" }
    edhrec_rank    { Faker::Number.between(from: 1, to: 1000) }
    legalities     { { "commander" => "legal" } }
    keywords       { [] }
    raw_data       { {} }

    trait :multicolor do
      color_identity { "U,B" }
      mana_cost      { "{U}{B}" }
    end

    trait :colorless do
      color_identity { "" }
      mana_cost      { "{5}" }
    end
  end
end
