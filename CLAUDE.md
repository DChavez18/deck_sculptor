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
- Models: Commander, Deck, DeckCard, CardCache
- 42 examples, 0 failures locally

## Models overview
- Commander — Scryfall card data for the chosen commander
- Deck — belongs to commander, holds 99 DeckCards
- DeckCard — a card in a deck with category, cmc, color_identity (string)
- CardCache — local Scryfall response cache, 7-day TTL

## Current task
Fixing CI failures on the phase-1-setup PR before merging.
Three jobs failing: lint (rubocop), scan_ruby (brakeman), test (rspec).

Run these locally and report full output before fixing anything:
1. bundle exec brakeman --no-pager
2. bundle exec rspec
3. bundle exec rubocop
```

Create that file, then at the start of every Claude Code session you just say "read CLAUDE.md and let's continue" and it's fully up to speed instantly. We should also make it a habit to update it at the end of each phase.

Once you've created it, start a new Claude Code session and paste:
```
Read CLAUDE.md then run these three commands and show me
the full output before fixing anything:

1. bundle exec brakeman --no-pager
2. bundle exec rspec
3. bundle exec rubocop
