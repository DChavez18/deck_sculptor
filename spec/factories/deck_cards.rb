FactoryBot.define do
  factory :deck_card do
    association :deck
    scryfall_id    { SecureRandom.uuid }
    card_name      { Faker::Games::LeagueOfLegends.champion }
    quantity       { 1 }
    category       { "creature" }
    mana_cost      { "{1}{U}" }
    cmc            { 2.0 }
    type_line      { "Creature — Human Wizard" }
    color_identity { "U" }
    oracle_text    { Faker::Lorem.sentence }
    image_uri      { "https://cards.scryfall.io/normal/front/placeholder.jpg" }
    raw_data       { {} }

    trait :land do
      category       { "land" }
      mana_cost      { "" }
      cmc            { 0.0 }
      type_line      { "Basic Land — Island" }
      color_identity { "" }
    end

    trait :creature do
      category       { "creature" }
      type_line      { "Creature — Human Wizard" }
      cmc            { 3.0 }
      mana_cost      { "{1}{U}{U}" }
      color_identity { "U" }
    end
  end
end
