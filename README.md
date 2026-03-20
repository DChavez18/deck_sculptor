# DeckSculptor

DeckSculptor is a Magic: The Gathering Commander (EDH) deck builder built with Rails 8. Named after Jace, the Mind Sculptor, it helps you search for commanders, assemble 99-card decks, score card suggestions by synergy, surface EDHREC popularity data, and detect infinite combos — all powered by free, key-less APIs.

## Features

- **Commander search** with live Turbo Frame results as you type
- **Deck builder** with auto-categorization of every card added (creature, instant, land, etc.)
- **Scored card suggestions** ranked by keyword synergy, mana curve fit, and category gaps
- **EDHREC popularity data** showing the most-played cards for your commander
- **Combo detection** via Commander Spellbook, scoped to your commander
- **Mana curve and strategy analysis** with category breakdown charts

## Setup

**Requirements:**
- Ruby 3.2.2 (see `.ruby-version`)
- PostgreSQL

```bash
bundle install
rails db:create db:migrate
bin/dev
```

Visit [http://localhost:3000](http://localhost:3000).

## Tech Stack

| Gem / Tool | Purpose |
|---|---|
| Rails 8 | Web framework |
| PostgreSQL | Database |
| Tailwind CSS (`tailwindcss-rails`) | Utility-first styling |
| Hotwire Turbo + Stimulus | SPA-like interactivity without JavaScript builds |
| HTTParty | External API HTTP client |
| Solid Cache / Solid Queue | Rails 8 default caching and background jobs (no Redis) |
| RSpec + FactoryBot + Faker | Testing |
| Shoulda Matchers | Concise model spec matchers |
| WebMock | Stub all external HTTP in tests |
| Brakeman | Static security analysis |
| RuboCop (`rubocop-rails-omakase`) | Code style |

## API Credits

All external data comes from free, no-key-required APIs:

- **[Scryfall](https://scryfall.com/docs/api)** — card search, images, metadata
- **[EDHREC](https://edhrec.com)** — commander popularity and card recommendations
- **[Commander Spellbook](https://commanderspellbook.com)** — combo database

## Running Tests

```bash
bundle exec rspec
```

## Running Linters / Security

```bash
bundle exec rubocop --autocorrect
bundle exec rubocop
bundle exec brakeman --no-pager
```

## Roadmap

- **Phase 5 — Strategy Analysis:** Archetype detection, color identity gap analysis, recommended ratios
- **Phase 6 — Commander Profile:** Full EDHREC commander page integration, combo synergy scoring
- **Phase 7 — Deployment:** Deploy to Railway with PostgreSQL, Solid Cache, and zero-downtime releases
