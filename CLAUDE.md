# DeckSculptor — Claude Code Context

## What this is
A Magic: The Gathering Commander deck builder app built with Rails 8.
Named after Jace, the Mind Sculptor.

## Core principles
- TDD always — write tests first with RSpec, never skip them
- Keep code simple and readable — no clever one-liners, no over-engineering
- Small focused methods that do one thing
- Descriptive naming over comments
- One feature branch per phase, PR into main, CI must be green before merging

## Tech stack
- Rails 8, PostgreSQL, Tailwind CSS, Hotwire (Turbo + Stimulus)
- RSpec, FactoryBot, Faker, Shoulda Matchers
- HTTParty for external API calls
- Solid Cache / Solid Queue (Rails 8 defaults, no Redis needed in dev)

## Free MTG APIs we use
- Scryfall API (primary) — card data, images, search. No key required.
- EDHREC — popularity and commander data
- Commander Spellbook — combo lookup
- MTGJson — bulk card data for local seeding

## Branch strategy
- main is protected — CI must pass before merging
- One branch per phase: phase-1-setup, phase-2-scryfall, etc.
- Commit messages follow: "Phase N: short description"

## Current status
- Phase 1 complete and merged — models, migrations, RSpec setup
- Phase 2 complete and merged — ScryfallService, WebMock, CardCache
- Phase 3 complete and merged — UI, controllers, views, CardCategorizer, Stimulus
- Phase 4 complete and merged — SuggestionEngine, EdhrecService, ComboFinderService, README
- Phase 4 hotfix complete and merged — commander selection, bracket level 1–5
- Phase 4 hotfix-2 complete and merged — live card search, card images in deck list
- Phase 5 complete and merged — strategy analysis, archetype detection, color gap analysis
- Phase 6 complete and merged — commander profile, EDHREC integration, combo synergy
- Phase 7 complete and merged — smarter suggestions, EDHREC fix, intent questionnaire, edit/delete
- Phase 8 complete and merged — flip card UI, thumbs up/down feedback, more-like-this suggestions
- Phase 9 complete and merged — intent-driven suggestions, Scryfall oracle tags, CardCognition, editable deck attributes
- Phase 10 complete and merged — Card model, deck-level blacklist, reliable thumbs-down persistence
- Phase 11 complete and merged — AI deck advisor chat (Claude API), DeckChat model, MTG guardrails
- Phase 12 complete and merged — UX polish, duplicate card guard, alphabetized card lists, Building Toward panel, load more fix
- Phase 13 in progress — UpgradeFinder tuning, upgrade card images, continued polish
- 421 examples, 0 failures
- CI green
- Currently on branch: `phase-13-polish-continued`

## What was built in Phase 10
- Card model — scryfall_id (unique), name, type_line, oracle_text, image_uri,
  cmc, color_identity; find_or_create_from_scryfall, to_scryfall_hash
- DeckCard and SuggestionFeedback optionally belong_to :card via nullable card_id FK
- blacklisted_card_ids PostgreSQL string array on Deck — blacklist_card(scryfall_id),
  card_blacklisted?(scryfall_id)
- Backfill migration copies existing thumbs-down scryfall_ids into the array
- ApplicationController#blacklisted? simplified to use card_blacklisted? + deck cards + commander
- SuggestionEngine and IntentEngine use deck.card_blacklisted? in excluded_from_suggestions?
- SuggestionFeedbacksController: blacklist_card called FIRST on thumbs-down before any API calls,
  fast cards_by_color_identity replacement (no slow engine pipeline)
- thumb_controller.js: removed card.remove() from thumbDown() — card removal
  now happens only via Turbo Stream response, not optimistic DOM removal
- Root cause of all previous blacklist failures: thumbDown() was destroying
  the form before Turbo could submit it
- 375 examples, 0 failures

## What was built in Phase 12
- Duplicate card guard — DeckCardsController#create rescues
  ActiveRecord::RecordNotUnique and redirects with flash error instead
  of crashing with a 500
- Alphabetized card lists — Deck#cards_by_category sorts cards
  alphabetically by card_name within each category
- Building Toward panel — deck show page displays win condition, playstyle,
  themes, and budget as progress/intent summary; only shown when intent
  is filled in (intent_completed?)
- Load more button fix — suggestions view only renders the Load More button
  when the total suggestion count before pagination exceeds 30; previously
  appeared incorrectly when fewer suggestions existed

## What was built in Phase 11
- AiAdvisorService — calls Claude API (claude-sonnet-4-20250514) with full
  deck context: commander, cards by category, strategy summary, bracket
  level, win condition, budget, playstyle, themes
- DeckChat model — deck_id, role (user/assistant), content, persists
  conversation history across page reloads
- AI Deck Advisor collapsible panel on deck show page — chat input, message
  history, streaming-style response display
- MTG guardrails in system prompt — keeps advisor focused on Magic strategy,
  rejects off-topic questions gracefully
- DecksController#chat action — POST endpoint, calls AiAdvisorService,
  persists both user message and assistant reply, responds with Turbo Stream
- Anthropic API key stored in Rails credentials under anthropic.api_key

## What was built in Phase 9
- IntentEngine service — builds suggestion pools from deck intent using Scryfall oracle tags
  (oracletag:ramp, oracletag:removal, oracletag:draw-card, oracletag:boardwipe,
  oracletag:counter-spell, oracletag:tutor, oracletag:token-generation,
  oracletag:graveyard-recursion)
- Win condition drives pools: combat → attack-trigger/combat-ramp, combo →
  tutor/graveyard-recursion, control → counter-spell/removal/boardwipe,
  tokens → token-generation, graveyard → graveyard-recursion
- Budget filtering, playstyle score modifiers, theme keyword boosting with liked_ids
  synergy boost
- ScryfallService#cards_by_function — Scryfall oracle tag queries, all queries include
  -is:digital game:paper legal:commander
- CardCognitionService — free API at api.cardcognition.com, real-world commander synergy
  scores from EDHREC data, +3 "High commander synergy" (>=0.5), +2 "Commander synergy"
  (>=0.2), 7-day cache
- MergeSuggestions — deduplicates both engines, keeps higher score, cap raised to 100
- Pagination — 30 initially, Load More button appends next 30 via Turbo Stream
- Editable deck attributes — win_condition, budget, playstyle, themes, bracket_level
  editable from deck edit page
- Intent summary panel on suggestions page — shows current intent with Edit Deck link
- Centralised blacklisted? helper in ApplicationController — checks id, scryfall_id
  fallback, name
- SuggestionEngine and IntentEngine both filter feedbacked cards internally via
  excluded_from_suggestions?
- Thumbs up: saves feedback, re-scores with liked_ids, injects 3 similar cards
- Thumbs down: removes card, injects 1 smart replacement using liked_ids
- Add to Deck from suggestions: Turbo Stream removes card from grid, no redirect
- Commander and deck cards excluded from suggestions by id and name
- 354 examples, 0 failures

## What was built in Phase 2
- app/services/scryfall_service.rb — search_commander, find_commander,
  search_cards, find_card_by_id, cards_by_color_identity, commander_suggestions
- spec/services/scryfall_service_spec.rb — 24 examples, all WebMock stubbed
- CardCache.fetch_by_name — ILIKE partial match added to model
- WebMock added to test group

## What was built in Phase 3
- config/routes.rb — full route set
- CardCategorizer service — categorizes cards by type_line
- CommandersController — search (Turbo Frame), show
- DecksController — index, new, create, show, suggestions, analysis
- DeckCardsController — create with auto-categorization, destroy
- Views — dark blue Tailwind theme throughout
- commander_search_controller.js — debounced Turbo Frame search

## What was built in Phase 4
- SuggestionEngine — scores cards by keyword synergy, curve gap, category fill
- EdhrecService — fetches EDHREC commander data, caches in CardCache
- ComboFinderService — queries Commander Spellbook for combo detection
- Updated suggestions view — score badges, reason tags, Add to Deck button
- Updated analysis view — combos section with Spellbook links
- Updated show view — progress bar, color pips, quick stats
- README.md — full project documentation

## What was fixed in Phase 4 hotfix
- Commander select button now writes Scryfall UUID to a hidden input via Stimulus
- Removed empty select dropdown — Commander.find_or_create_from_scryfall()
  upserts the record at deck creation time using ScryfallService
- Renamed power_level to bracket_level (1-5 scale) via migration
- Deck::BRACKET_LEVELS constant, validation, views, factory, and specs all updated

## What was fixed in Phase 4 hotfix-2
- Add Card form now uses live search dropdown via CardsController#search
- ScryfallService#find_card_by_name added (fuzzy name lookup with caching)
- DeckCardsController#create falls back to name lookup when scryfall_id is blank
- Card images (small thumbnails) shown in deck card list using Scryfall small CDN URL
- card_search_controller.js — debounced search, populates hidden inputs on select,
  validates before submit, hides dropdown on outside click

## What was built in Phase 5
- ArchetypeDetector — keyword scoring across oracle_text to detect
  combo/aggro/control/stax/midrange/goodstuff
- ColorGapAnalyzer — identifies missing colors, off-color cards, color distribution
- StrategyAnalyzer — orchestrates both, returns detected_archetype, color_gaps,
  strategy_summary, key_themes
- SuggestionEngine updated — archetype_boost weights suggestions toward detected
  archetype's card types
- analysis view — strategy panel with archetype badge, key themes, summary,
  color gap warnings
- Card quantity adjustment — plus/minus controls, basic land detection, PATCH endpoint
- Turbo Stream quantity updates — in-place update of stats and card list, no scroll jump
- Auto-submit card search — selecting from dropdown immediately adds card to deck
- Collapsible category sections — chevron toggle, space-y-4 gap between groups

## What was built in Phase 6
- Commander profile page (/commanders/:id) — large card image, oracle text,
  color pips, EDHREC rank, link to EDHREC, top 10 popular cards, known combos
- EdhrecService#top_cards_with_details — returns structured card list with
  name, synergy, inclusion, category, reason. Gracefully returns [] on failure
- SuggestionEngine combo synergy boost — +3 and "Combo piece" tag when a
  suggested card appears in a combo with 2+ cards already in the deck
- Commander image and name on deck show page are clickable links to profile
- New deck form — commander card preview shown after selecting from search
- New deck form — pre-populates commander when arriving from profile page

## What was built in Phase 7
- Fixed EDHREC integration — data now read from container/json_dict/cardlists,
  merging highsynergycards, topcards, gamechangers lists
- Tiered EDHREC synergy scoring — +3 "High synergy staple" (>=0.3), +2
  "Commander staple" (>=0.1), +1 "Popular pick" (>0)
- EdhrecService#commander_themes — pulls theme tags from EDHREC panels
- Commander profile — EDHREC theme tags shown as pill badges
- RatioAnalyzer — card type ratio targets vs actuals with cut suggestions
- CurveAdvisor — plain English mana curve recommendations
- Analysis page — Card Type Ratios panel and Mana Curve Recommendations
- Deck edit/delete — pencil/trash icons on index (hover), Edit Deck button on show
- Intent questionnaire — after deck creation, 4-question form captures win
  condition, budget, playstyle, themes; redirects to deck show on save
- Theme-based suggestion boost — +2 per matching theme keyword in oracle_text,
  capped at +4, with "Matches your theme: X" reason tags
- Fixed commander pre-selection bug — hidden input moved inside form

## What was built in Phase 8
- SuggestionFeedback model — deck_id, scryfall_id, card_name, feedback (up/down),
  unique index on [deck_id, scryfall_id], belongs_to :deck
- SuggestionFeedbacksController#create — upserts feedback; thumbs DOWN responds
  with Turbo Stream remove; thumbs UP calls more_like and appends new cards
- SuggestionEngine#more_like — fetches liked cards from CardCache, extracts shared
  keyword/type/CMC signals, scores candidates against signals, returns top 3 not
  already in deck or already given feedback
- card_flip_controller.js — Stimulus controller toggling .is-flipped class +
  stopPropagation; front face shows full card art uncropped at natural aspect ratio
- card_text_controller.js — expand/collapse with stopPropagation so show more/less
  does not trigger card flip
- thumb_controller.js — optimistic client-side thumbs highlight on click; thumbs
  down optimistically removes card from DOM before Turbo Stream confirm
- 3D CSS card flip — perspective wrapper, preserve-3d inner, backface-visibility,
  .is-flipped rotates 180deg on Y axis, transition 0.4s; front face uses
  position relative to drive natural height, back face position absolute overlays
- _suggestion_card.html.erb partial — front face (full art only, no overlays) /
  back face (score badge, reason tags, oracle text with show more/less, Add to
  Deck, thumbs SVG buttons); cards without image skip flip and show back face only
- Suggestions view wraps grid in id="suggestions-grid" for Turbo Stream targeting
- Thumbs highlighted green (up) or red (down) when feedback already saved for deck
- 285 examples, 0 failures

## Models overview
- Commander — Scryfall card data for the chosen commander
- Deck — belongs to commander, holds 99 DeckCards; has win_condition, budget,
  playstyle, themes, intent_completed, bracket_level fields
- DeckCard — a card in a deck with category, cmc, color_identity (string)
- CardCache — local Scryfall response cache, 7-day TTL
- SuggestionFeedback — per-deck per-card thumbs up/down signal, unique on
  [deck_id, scryfall_id]
- Card — scryfall_id (unique), name, type_line, oracle_text, image_uri, cmc,
  color_identity; find_or_create_from_scryfall, to_scryfall_hash

## Upcoming phases
- Phase 13: UpgradeFinder scoring tuning, upgrade card images, polish
- Phase 14: Deployment to Railway

## Current task
Phase 13 in progress — fixing UpgradeFinder so it stops suggesting
sidegrades (e.g. Rhystic Study → Mystic Barrier). Tuning the scoring
to require functional similarity and meaningful power delta. Also adding
card images to the upgrade suggestions layout on the analysis page.
