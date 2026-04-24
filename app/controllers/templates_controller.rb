class TemplatesController < ApplicationController
  allow_unauthenticated_access

  TEMPLATES = [
    {
      id:          "aggro-beatdown",
      name:        "Aggro Beatdown",
      description: "Go wide with cheap creatures and attack for lethal damage early. Prioritize haste and evasion to punch through defenses. Win before your opponents can set up their game plans.",
      color_identity: "Red/White",
      archetype:   "aggro",
      win_condition: "Combat damage",
      themes:      "haste, tokens, attack",
      bracket_level: 2,
      recommended_card_count_by_category: {
        creatures: 35, ramp: 8, removal: 8, card_draw: 6, protection: 5, utility: 3, lands: 35
      },
      example_commanders: [
        { name: "Winota, Joiner of Forces",    note: "Triggers when non-Humans attack, fetching powerful Humans for free" },
        { name: "Rith, the Awakener",           note: "Creates Saproling tokens whenever it deals combat damage" },
        { name: "Adriana, Captain of the Guard", note: "Grants melee to all attackers, scaling with the number of opponents attacked" }
      ]
    },
    {
      id:          "combo-control",
      name:        "Combo Control",
      description: "Assemble a game-winning infinite combo while protecting it with counterspells and removal. Draw cards to find your pieces quickly and deny opponents the time they need.",
      color_identity: "Blue/Black",
      archetype:   "combo",
      win_condition: "Infinite combo",
      themes:      "tutors, counters, infinite",
      bracket_level: 4,
      recommended_card_count_by_category: {
        creatures: 15, instants: 15, sorceries: 8, artifacts: 10, card_draw: 10, ramp: 8, lands: 34
      },
      example_commanders: [
        { name: "Thrasios, Triton Hero",    note: "Infinite mana sink that draws your entire library" },
        { name: "Breya, Etherium Shaper",   note: "Four-color artifact combo with multiple infinite lines" },
        { name: "Zur the Enchanter",         note: "Tutors key enchantments directly onto the battlefield" }
      ]
    },
    {
      id:          "token-swarm",
      name:        "Token Swarm",
      description: "Flood the board with token creatures and overwhelm opponents through sheer numbers. Use anthems and token doublers to turn your army into an unstoppable force.",
      color_identity: "Green/White",
      archetype:   "aggro",
      win_condition: "Combat damage",
      themes:      "tokens, populate, go wide, anthem",
      bracket_level: 3,
      recommended_card_count_by_category: {
        creatures: 25, enchantments: 12, instants: 5, sorceries: 8, ramp: 10, card_draw: 5, lands: 35
      },
      example_commanders: [
        { name: "Rhys the Redeemed",    note: "Creates Elves early then doubles your token count for six mana" },
        { name: "Trostani, Selesnya's Voice", note: "Populates your best token and gains massive life" },
        { name: "Adeline, Resplendent Cathar", note: "Creates a token for each opponent you attack every combat" }
      ]
    },
    {
      id:          "graveyard-recursion",
      name:        "Graveyard Recursion",
      description: "Fill your graveyard with powerful threats and repeatedly reanimate them to overwhelm opponents. Generate incremental value by recurring key pieces turn after turn.",
      color_identity: "Black/Green",
      archetype:   "midrange",
      win_condition: "Combat damage",
      themes:      "graveyard, recursion, reanimate, sacrifice",
      bracket_level: 3,
      recommended_card_count_by_category: {
        creatures: 30, sorceries: 8, instants: 5, enchantments: 6, ramp: 10, card_draw: 6, lands: 35
      },
      example_commanders: [
        { name: "Meren of Clan Nel Toth",    note: "Returns creatures from the graveyard for free based on experience counters" },
        { name: "The Gitrog Monster",         note: "Draws cards from land drops and fills the graveyard at breakneck speed" },
        { name: "Muldrotha, the Gravetide",   note: "Replays one permanent of each type from your graveyard each turn" }
      ]
    },
    {
      id:          "spellslinger",
      name:        "Spellslinger",
      description: "Cast a high volume of instants and sorceries to trigger powerful spell-matters effects. Copy your best spells and chain them together for explosive turns.",
      color_identity: "Blue/Red",
      archetype:   "combo",
      win_condition: "Card advantage engine",
      themes:      "instant, sorcery, spellslinger, copy, storm",
      bracket_level: 3,
      recommended_card_count_by_category: {
        instants: 20, sorceries: 15, creatures: 10, artifacts: 8, enchantments: 5, ramp: 8, lands: 34
      },
      example_commanders: [
        { name: "Niv-Mizzet, Parun",          note: "Draws a card for each spell cast and pings opponents with each draw" },
        { name: "Mizzix of the Izmagnus",      note: "Reduces the cost of instants and sorceries via experience counters" },
        { name: "Melek, Izzet Paragon",        note: "Copies the top instant or sorcery you cast each turn" }
      ]
    },
    {
      id:          "ramp-and-stomp",
      name:        "Ramp and Stomp",
      description: "Accelerate your mana production to cast enormous threats ahead of schedule. Use the mana advantage to deploy game-ending creatures that are too large for opponents to handle.",
      color_identity: "Green",
      archetype:   "midrange",
      win_condition: "Combat damage",
      themes:      "ramp, big creatures, stomp, landfall",
      bracket_level: 3,
      recommended_card_count_by_category: {
        creatures: 30, ramp: 15, card_draw: 8, removal: 5, protection: 3, lands: 34
      },
      example_commanders: [
        { name: "Selvala, Heart of the Wilds", note: "Generates enormous amounts of mana from the largest creature" },
        { name: "Goreclaw, Terror of Qal Sisma", note: "Reduces the cost of large creatures and gives them trample and haste" },
        { name: "Omnath, Locus of Mana",        note: "Stores excess green mana between turns for massive plays" }
      ]
    }
  ].freeze

  def index
    @templates = TEMPLATES
  end

  def show
    @template = TEMPLATES.find { |t| t[:id] == params[:archetype] }
    render plain: "Template not found", status: :not_found unless @template
  end
end
