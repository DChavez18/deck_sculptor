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
- Phase 6 complete — commander profile, EDHREC integration, combo synergy boost,
  commander preview on new deck form
- 201 examples, 0 failures
- CI green
- Currently on branch: `phase-6-commander-profile` — ready to PR into main

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
- Removed empty <select> dropdown — Commander.find_or_create_from_scryfall()
  upserts the record at deck creation time using ScryfallService
- Renamed power_level → bracket_level (1–5 scale) via migration
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
- Card quantity adjustment — +/− controls, basic land detection, PATCH endpoint
- Turbo Stream quantity updates — in-place update of stats and card list, no scroll jump
- Auto-submit card search — selecting from dropdown immediately adds card to deck
- Collapsible category sections — chevron toggle, space-y-4 gap between groups

## What was built in Phase 6
- Commander profile page (/commanders/:id) — large card image, oracle text,
  color pips, EDHREC rank, link to EDHREC, top 10 popular cards, known combos
- EdhrecService#top_cards_with_details — returns structured card list with
  name, category, reason. Gracefully returns [] on failure
- SuggestionEngine combo synergy boost — +3 and "Combo piece" tag when a
  suggested card appears in a combo with 2+ cards already in the deck
- Commander image and name on deck show page are clickable links to profile
- New deck form — commander card preview shown after selecting from search
  (image links to profile, "Change commander" resets to search)
- New deck form — pre-populates commander when arriving from profile page
  via ?commander_id= param

## Models overview
- Commander — Scryfall card data for the chosen commander
- Deck — belongs to commander, holds 99 DeckCards
- DeckCard — a card in a deck with category, cmc, color_identity (string)
- CardCache — local Scryfall response cache, 7-day TTL

## Upcoming phases
- Phase 7: Smarter suggestions + analysis deep dive
- Phase 8: AI deck advisor chat (Claude API)
- Phase 9: Deployment to Railway

## What Phase 7 will build
- Pull commander-specific staples from EDHREC to seed suggestion pool
- Filter cards already in the deck from suggestions
- Boost EDHREC top cards in suggestion scoring
- Analysis page: card type ratio targets vs actuals
- Analysis page: mana curve recommendations
- Analysis page: cuts suggestions based on ratio targets

## What Phase 8 will build
- AI chat panel on suggestions page powered by Claude API
- Full deck context passed as system prompt
- Users can ask: why is this card good, what should I cut, how to improve
  mana base, what's the win condition, unique cards for my theme

## Current task
Phase 6 complete — commit CLAUDE.md, push phase-6-commander-profile,
PR into main, then create branch phase-7-suggestions and begin Phase 7.
