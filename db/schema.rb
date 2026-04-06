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

ActiveRecord::Schema[8.1].define(version: 2026_04_06_220823) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "card_caches", force: :cascade do |t|
    t.datetime "cached_at", null: false
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}
    t.string "name", null: false
    t.string "scryfall_id", null: false
    t.datetime "updated_at", null: false
    t.index ["cached_at"], name: "index_card_caches_on_cached_at"
    t.index ["name"], name: "index_card_caches_on_name"
    t.index ["scryfall_id"], name: "index_card_caches_on_scryfall_id", unique: true
  end

  create_table "cards", force: :cascade do |t|
    t.decimal "cmc", precision: 4, scale: 1
    t.string "color_identity"
    t.datetime "created_at", null: false
    t.string "image_uri"
    t.string "name", null: false
    t.text "oracle_text"
    t.string "scryfall_id", null: false
    t.string "type_line"
    t.datetime "updated_at", null: false
    t.index ["scryfall_id"], name: "index_cards_on_scryfall_id", unique: true
  end

  create_table "commanders", force: :cascade do |t|
    t.string "color_identity"
    t.datetime "created_at", null: false
    t.integer "edhrec_rank"
    t.string "image_uri"
    t.string "keywords", default: [], array: true
    t.jsonb "legalities", default: {}
    t.string "mana_cost"
    t.string "name", null: false
    t.text "oracle_text"
    t.jsonb "raw_data", default: {}
    t.string "scryfall_id", null: false
    t.string "type_line"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_commanders_on_name"
    t.index ["scryfall_id"], name: "index_commanders_on_scryfall_id", unique: true
  end

  create_table "deck_cards", force: :cascade do |t|
    t.bigint "card_id"
    t.string "card_name", null: false
    t.string "category"
    t.decimal "cmc", precision: 4, scale: 1
    t.string "color_identity"
    t.datetime "created_at", null: false
    t.bigint "deck_id", null: false
    t.string "image_uri"
    t.string "mana_cost"
    t.text "oracle_text"
    t.integer "quantity", default: 1
    t.jsonb "raw_data", default: {}
    t.string "scryfall_id", null: false
    t.string "type_line"
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_deck_cards_on_card_id"
    t.index ["category"], name: "index_deck_cards_on_category"
    t.index ["deck_id", "scryfall_id"], name: "index_deck_cards_on_deck_id_and_scryfall_id", unique: true
    t.index ["deck_id"], name: "index_deck_cards_on_deck_id"
  end

  create_table "deck_chats", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.bigint "deck_id", null: false
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.index ["deck_id"], name: "index_deck_chats_on_deck_id"
  end

  create_table "decks", force: :cascade do |t|
    t.string "archetype"
    t.string "blacklisted_card_ids", default: [], array: true
    t.integer "bracket_level", default: 3
    t.string "budget"
    t.bigint "commander_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "intent_completed", default: false
    t.string "name", null: false
    t.text "themes"
    t.datetime "updated_at", null: false
    t.string "win_condition"
    t.index ["commander_id"], name: "index_decks_on_commander_id"
  end

  create_table "suggestion_feedbacks", force: :cascade do |t|
    t.bigint "card_id"
    t.string "card_name", null: false
    t.datetime "created_at", null: false
    t.bigint "deck_id", null: false
    t.string "feedback", null: false
    t.string "scryfall_id", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_suggestion_feedbacks_on_card_id"
    t.index ["deck_id", "scryfall_id"], name: "index_suggestion_feedbacks_on_deck_id_and_scryfall_id", unique: true
    t.index ["deck_id"], name: "index_suggestion_feedbacks_on_deck_id"
  end

  add_foreign_key "deck_cards", "cards"
  add_foreign_key "deck_cards", "decks"
  add_foreign_key "deck_chats", "decks"
  add_foreign_key "decks", "commanders"
  add_foreign_key "suggestion_feedbacks", "cards"
  add_foreign_key "suggestion_feedbacks", "decks"
end
