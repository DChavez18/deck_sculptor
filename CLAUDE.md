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
- Phase 5 complete — strategy analysis, archetype detection, color gap analysis
- 184 examples, 0 failures
- CI green
- Currently on branch: `phase-5-strategy` — ready to PR into main

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

## Models overview
- Commander — Scryfall card data for the chosen commander
- Deck — belongs to commander, holds 99 DeckCards
- DeckCard — a card in a deck with category, cmc, color_identity (string)
- CardCache — local Scryfall response cache, 7-day TTL

## Upcoming phases
- Phase 6: Commander profile — full EDHREC integration, combo synergy
- Phase 7: Deployment to Railway

## Current task
Phase 5 complete — commit CLAUDE.md, push phase-5-strategy, PR into main,
then create branch phase-6-commander-profile and begin Phase 6.
