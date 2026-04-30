# DeckSculptor

DeckSculptor is a Magic: The Gathering Commander (EDH) deck builder built with Rails 8. Named after Jace, the Mind Sculptor, it helps you search for commanders, assemble 99-card decks, score card suggestions by synergy, surface EDHREC popularity data, and detect infinite combos — all powered by free, key-less APIs.

## Features

- **Commander search** with live Turbo Frame results as you type
- **Deck builder** with auto-categorization of every card added (creature, instant, land, etc.)
- **Scored card suggestions** ranked by keyword synergy, mana curve fit, and category gaps
- **EDHREC popularity data** showing the most-played cards for your commander
- **Combo detection** via Commander Spellbook, scoped to your commander
- **Mana curve and strategy analysis** with category breakdown charts
- **AI deck advisor chat** powered by Claude — ask questions about your deck and get MTG-focused advice
- **Persistent chat history** per deck, stored across page reloads
- **Alphabetized card display** within each category for easier scanning
- **Duplicate card protection** — adding a card already in your deck shows a friendly error instead of a crash
- **Functional card categorization** — oracle-text-based categories (ramp, draw, removal, etc.) with clickable category pages showing full card image grids
- **MDFC support** — split/modal double-faced cards tracked with secondary categories so land-back MDFCs count toward both removal and land totals
- **Suggestion filters** — filter suggestions by Card Draw, Ramp, Removal, Board Wipes, Lands, Combos with commander-synergy-first ranking powered by EDHREC
- **Deck type grouping** — deck card list groups by card type (Creature, Instant, etc.) with smart MDFC handling
- **User accounts** — sign up with Google in one click, or use email/password if you prefer
- **Anonymous deck building** — start building a deck without signing in; your decks are automatically saved to your account when you sign up or sign in

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

### Google OAuth (optional for local dev)

The app supports Google SSO via omniauth-google-oauth2. For local
development you can skip this and use email/password signup instead. To
enable Google signin locally:

1. Create an OAuth client in the [Google Cloud Console](https://console.cloud.google.com)
   (APIs & Services → Credentials → Create OAuth Client ID → Web application)
2. Add `http://localhost:3000/auth/google_oauth2/callback` as an
   authorized redirect URI
3. Add the credentials to your Rails credentials file:

```bash
bin/rails credentials:edit
```

```yaml
google:
  client_id: your-client-id.apps.googleusercontent.com
  client_secret: your-client-secret
```

### Anthropic API key (required for AI deck advisor)

```bash
bin/rails credentials:edit
```

```yaml
anthropic:
  api_key: sk-ant-...
```

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

## Phase History

| Phase | What shipped |
|---|---|
| 1 | Models, migrations, RSpec setup |
| 2 | ScryfallService, WebMock, CardCache |
| 3 | UI, controllers, views, CardCategorizer, Stimulus |
| 4 | SuggestionEngine, EdhrecService, ComboFinderService |
| 4 hotfix | Commander selection, bracket level 1–5 |
| 4 hotfix-2 | Live card search, card images in deck list |
| 5 | Strategy analysis, archetype detection, color gap analysis |
| 6 | Commander profile page, EDHREC integration, combo synergy |
| 7 | Smarter suggestions, EDHREC fix, intent questionnaire, edit/delete |
| 8 | Flip card UI, thumbs up/down feedback, more-like-this suggestions |
| 9 | Intent-driven suggestions, Scryfall oracle tags, CardCognition, editable deck attributes |
| 10 | Card model, deck-level blacklist, reliable thumbs-down persistence |
| 11 | AI deck advisor chat (Claude API), DeckChat model, MTG guardrails |
| 12 | UX polish, duplicate card guard, alphabetized card lists, Building Toward panel, load more fix |
| 13 | UpgradeFinder tuning, upgrade card images, continued polish |
| 14 | CardCategorizer rewrite, clickable category pages, MDFC support |
| 15 | Deck type grouping, suggestion filters, EDHREC scoring boost, N+1 fixes |
| 16 | Railway deployment, mobile responsive fixes, healthcheck route |
| 16 hotfix | Fix Railway healthcheck (startCommand, puma bind, bypass Thruster) |
| 17 | Authentication: Rails 8 auth, Google SSO, anonymous deck claim flow |
| 17 hotfix 1 | Manual production migrations via railway ssh |
| 17 hotfix 2 | Disable Turbo on Google signin button (CORS preflight fix) |
| 17 polish | Show/hide password toggle on signin and signup |
| 18 | Card image hover-zoom on laptop, tap-to-modal on mobile |
| 18 hotfix | Fix add-card-from-search not updating deck list (Turbo Stream targeted suggestions DOM only) |
| 18 hotfix | Building Toward panel now counts cards in every role they fulfill — creatures that ramp/draw/remove count toward both Creature and the functional bucket |

## Roadmap

- **Phase 18 — Suggestion polish:** Refined suggestion filters and improved combos page (target: post-MagicCon May 1)
- **Post-MagicCon:** Automatic migrations in deploy entrypoint, custom domain (decksculptor.com pending), password reset UI, profile editing
