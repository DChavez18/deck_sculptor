FactoryBot.define do
  factory :card do
    scryfall_id    { SecureRandom.uuid }
    name           { Faker::Games::LeagueOfLegends.champion }
    type_line      { "Artifact" }
    oracle_text    { Faker::Lorem.sentence }
    image_uri      { "https://cards.scryfall.io/normal/front/placeholder.jpg" }
    cmc            { 2.0 }
    color_identity { "" }
  end
end
