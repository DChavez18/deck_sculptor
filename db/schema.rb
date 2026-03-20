# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_03_20_172407) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "card_caches", force: :cascade do |t|
    t.string "scryfall_id", null: false
    t.string "name", null: false
    t.jsonb "data", default: {}
    t.datetime "cached_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cached_at"], name: "index_card_caches_on_cached_at"
    t.index ["name"], name: "index_card_caches_on_name"
    t.index ["scryfall_id"], name: "index_card_caches_on_scryfall_id", unique: true
  end

  create_table "commanders", force: :cascade do |t|
    t.string "scryfall_id", null: false
    t.string "name", null: false
    t.string "color_identity"
    t.string "type_line"
    t.text "oracle_text"
    t.string "mana_cost"
    t.string "image_uri"
    t.integer "edhrec_rank"
    t.jsonb "legalities", default: {}
    t.string "keywords", default: [], array: true
    t.jsonb "raw_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_commanders_on_name"
    t.index ["scryfall_id"], name: "index_commanders_on_scryfall_id", unique: true
  end

  create_table "deck_cards", force: :cascade do |t|
    t.bigint "deck_id", null: false
    t.string "scryfall_id", null: false
    t.string "card_name", null: false
    t.integer "quantity", default: 1
    t.string "category"
    t.string "mana_cost"
    t.decimal "cmc", precision: 4, scale: 1
    t.string "type_line"
    t.string "color_identity"
    t.text "oracle_text"
    t.string "image_uri"
    t.jsonb "raw_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_deck_cards_on_category"
    t.index ["deck_id", "scryfall_id"], name: "index_deck_cards_on_deck_id_and_scryfall_id", unique: true
    t.index ["deck_id"], name: "index_deck_cards_on_deck_id"
  end

  create_table "decks", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "commander_id", null: false
    t.text "description"
    t.string "archetype"
    t.integer "power_level", default: 5
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["commander_id"], name: "index_decks_on_commander_id"
  end

  add_foreign_key "deck_cards", "decks"
  add_foreign_key "decks", "commanders"
end
