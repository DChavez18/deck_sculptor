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

## Development workflow
IMPORTANT: Always run `bin/rubocop -a` before every commit and fix any
offenses. CI runs rubocop and will fail if there are violations. The most
common offense is Layout/SpaceInsideArrayLiteralBrackets — use spaces
inside array brackets: [ "a", "b" ] not ["a", "b"].

## Current status
- Live at https://web-production-aefc3.up.railway.app
- 598 examples, 0 failures, CI green
- Currently on branch: `chore-trim-claude-md`
- Most recent work: Phase 20.2 — Reset filters button on suggestions page
- Full phase history: see README.md

## Models overview
- User — email (unique), password_digest (nullable, for email/password
  signup), google_uid (unique, nullable, for SSO); has_many :decks,
  has_many :sessions
- Session — belongs to User, stores ip_address and user_agent; Rails 8
  built-in session-based auth (not JWT, not Devise)
- Commander — Scryfall card data for the chosen commander
- Deck — belongs to commander, belongs_to :user (optional), holds 99
  DeckCards; has win_condition, budget, playstyle, themes,
  intent_completed, bracket_level, anonymous_session_token fields. A
  deck must have either a user_id OR an anonymous_session_token but not
  neither (validation-enforced, not DB-enforced)
- DeckCard — a card in a deck with category, cmc, color_identity, and a
  secondary_categories string column for MDFC/split card support
- CardCache — local Scryfall response cache, 7-day TTL
- SuggestionFeedback — per-deck per-card thumbs up/down signal, unique on
  [deck_id, scryfall_id]
- Card — scryfall_id (unique), name, type_line, oracle_text, image_uri, cmc,
  color_identity; find_or_create_from_scryfall, to_scryfall_hash
- DeckChat — deck_id, role (user/assistant), content; persists AI advisor
  conversation history across page reloads

## Authentication architecture
- Rails 8 built-in authentication is the base — generated via
  `bin/rails generate authentication`. No Devise.
- Google SSO via omniauth-google-oauth2 + omniauth-rails_csrf_protection
- Email/password is the fallback path; Google is primary
- Password reset infrastructure exists (from the generator) but isn't
  promoted in the UI — users who forget their password can either make
  a new account or use Google
- Current user accessed via `Current.user` (Rails 8 CurrentAttributes
  pattern), set in the Authentication concern's before_action
- Anonymous users get a signed `anonymous_session_token` cookie (6-month
  expiry) set by ApplicationController. Decks created while logged out
  store this token. On signin/signup, all decks with a matching token
  are reassigned to the new user and the token is nulled out.
- Authorization is scope-based, not role-based: decks visible to a user
  are those where user_id matches Current.user.id, or (for anonymous
  users) where anonymous_session_token matches the signed cookie. No
  admin role exists yet.

## Railway deployment
Live URL: https://web-production-aefc3.up.railway.app
Required environment variables in Railway dashboard:
- `RAILS_MASTER_KEY` — contents of config/master.key
- `DATABASE_URL` — provided automatically by Railway PostgreSQL plugin
- `ANTHROPIC_API_KEY` — your Anthropic API key for the AI advisor
- `RAILS_ENV=production`
- `GOOGLE_CLIENT_ID` — from Google Cloud Console OAuth client
- `GOOGLE_CLIENT_SECRET` — from Google Cloud Console OAuth client

Deployment notes (learned the hard way):
- railway.toml should NOT contain a `startCommand` — Railway runs it in
  exec form (no shell), so `&&` operators silently fail and no process
  starts. Let the Dockerfile's ENTRYPOINT and CMD handle startup.
- railway.toml should NOT contain a `[build]` section — Railway
  auto-detects the Dockerfile and uses it directly.
- config/puma.rb uses only `port ENV.fetch("PORT", 3000)` — no separate
  `bind` directive; the `port` directive binds 0.0.0.0 by default.
- Dockerfile CMD is `["./bin/rails", "server"]` NOT
  `["./bin/thrust", ...]` — Thruster listens on port 80 and ignores
  Railway's dynamic $PORT, breaking healthchecks. Puma serves directly.
- `bin/docker-entrypoint` runs `db:prepare` (primary database) followed
  by explicit `db:migrate:cache db:migrate:queue db:migrate:cable` for
  the three secondary logical databases. All four commands run on every
  deploy; they are idempotent so no manual `railway ssh` intervention is
  needed for migrations. See "Solid Cache / Solid Queue / Solid Cable
  migration hotfix" section for why the explicit secondary commands are
  required rather than relying on `db:prepare` alone.
- Turbo Drive intercepts form submissions and submits via fetch.
  For OAuth flows where the form must do a top-level redirect to a
  third party, add `data: { turbo: false }` to the form/button to
  bypass Turbo and do a normal browser POST.

## Google OAuth setup
OAuth client configured at https://console.cloud.google.com (project:
deck-sculptor-494719). Authorized redirect URIs:
- https://web-production-aefc3.up.railway.app/auth/google_oauth2/callback
- http://localhost:3000/auth/google_oauth2/callback

For local dev, add GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET to
Rails credentials under the `google:` key, or to a .env file. In
production they are set as Railway environment variables.

Note: as of MagicCon prep, the OAuth consent screen is still in
"Testing" mode with explicit test users on the allowlist. Before
the demo, click "PUBLISH APP" on the Google Auth Platform > Audience
page so any Gmail user can sign in. For the basic email/profile
scopes used here, no Google verification review is required —
publish is instant.

## Categorization: types vs roles

Two separate categorization systems coexist — keep them separate.

**Deck list grouping — `cards_by_type` (structural)**
Groups cards under Creature, Instant, Sorcery, Artifact, Enchantment,
Planeswalker, Land using `Deck::TYPE_LABELS` and `DISPLAY_ORDER` constants.
Land priority in bucketing ensures multi-type cards like Urza's Saga
(Enchantment Land) appear under Land, not Enchantment. Land section header
shows "Land · N cards · M MDFC" format.

Every Turbo Stream path that re-renders the deck card list must pass
`@deck.cards_by_type` — passing `cards_by_category` flips the section
headers to functional labels (Ramp, Draw, Removal), which is wrong for
the deck list. The three paths that had this bug and were fixed are:
`DeckCardsController#create`, `deck_cards/update.turbo_stream.erb`, and
`DeckImportsController#create`. Contract tests use Bloom Tender (a Creature
that also ramps) as the canonical case: Turbo Stream responses must render
a "Creature" section header and must NOT render a "Ramp" section header.

**Building Toward panel — `CardCategorizer#all_roles` (functional)**
Uses a priority waterfall: land → ramp → draw → board_wipe → removal →
tutor → protection → creature → type fallback. A card can fulfill multiple
roles; a Creature that ramps counts in both the Creature bucket and the Ramp
bucket in the Building Toward panel. Lands explicitly return `["land"]` only,
even when oracle text contains `{T}: Add {X}` mana text — to avoid false
ramp credit. `RatioAnalyzer#compute_actuals` calls `all_roles` from stored
`type_line` + `oracle_text` — no re-fetch needed, retroactively correct for
all existing decks.

**Why both exist**
Multi-role cards like Bloom Tender should appear in exactly one deck list
section (Creature) but count toward both the Creature and Ramp targets in
the Building Toward progress panel. Collapsing to a single system would
either fragment the deck list or undercount the progress panel.

**Known inconsistency**
`_deck_stats.html.erb:29` "Top Category" quick stat calls
`deck.cards_by_category` directly, showing a functional label ("ramp",
"draw") in that one spot while the rest of the show page groups by
structural type. Intentional for now; deferred until a functional-role
filter UI is added to the deck card list.

## NL prompt search architecture

**LLM as parser, not generator**
`NlPromptParserService` calls Claude API (claude-sonnet-4-20250514, max 256
tokens) with a system prompt that instructs it to return ONLY JSON — no
prose. On API error or JSON parse failure it returns nil (no filter applied,
suggestions page shows full unfiltered pool).

**FilterSpec hash schema**
`filter_type` (type | similarity | combo), `types`, `subtypes`, `colors`,
`max_cmc`, `min_cmc`, `keywords`, `reference_card`

**Three filter types (SuggestionFilter)**
All filtering is plain Ruby against the already-scored suggestion pool —
no AR queries, no additional API calls for type filters.
- `type`: AND-chains all present spec fields against card["type_line"],
  ["color_identity"], ["cmc"], ["keywords"]
- `similarity`: score-based, threshold 2 of 4 signals (subtype overlap,
  keyword overlap, CMC ±2, color overlap). One Scryfall lookup for the
  reference card (cached). Tests pinned with Sol Ring, Lightning Bolt, and
  Rhystic Study as canonical cases.
- `combo`: `ComboFinderService.find_combos([reference_card])` → keeps cards
  that appear as combo partners. Reuses existing Commander Spellbook
  integration with no new infrastructure.

**Caching and session scoping**
Caches by SHA256(prompt.downcase), 5-min TTL via Solid Cache.
Session key: `session[:nl_filter_specs][deck_id]` — prevents filter leaking
across decks in the same tab session. `GET #suggestions` always clears the
key so a page reload is always unfiltered. `#more_suggestions` reads it so
pagination respects an active filter.

**Filter composition**
NL filter narrows the pool server-side. Category pills and name search
narrow client-side via Stimulus. Logical AND; the two layers don't
interfere.

**Cross-controller coordination (Reset button)**
The Reset button lives in `suggestion_filter_controller.js` and delegates
to `nl-prompt#clear()` via a Stimulus outlet. The outer suggestion-filter
div gets `data-suggestion-filter-nl-prompt-outlet="#nl-prompt-controller"`;
the nl-prompt div gets `id="nl-prompt-controller"`. Inside `reset()`:
`this.nlPromptOutlet.clear()` calls the controller instance directly.
Outlets are the canonical Stimulus cross-controller pattern — avoids
querySelector and keeps each controller's internals encapsulated.
Button starts disabled (HTML attribute); `updateResetButton()` enables it
whenever any filter layer is active.

**Known race**
`reset()` calls `requestSubmit()` but Turbo does not abort in-flight
submits. A slow LLM response (1–3 s) arriving after the reset response
(~50 ms) could clobber the reset. In practice not observable since the
reset path skips the LLM entirely. Not handled in v1.

Phase 20 was production-broken from merge until the Solid Cache hotfix;
see "Solid Cache / Solid Queue / Solid Cable migration hotfix" for root cause.

## Implementation gotchas

**EDHREC data path**
`EdhrecService` reads card data from `container > json_dict > cardlists`,
merging the `highsynergycards`, `topcards`, and `gamechangers` lists.
Scoring weights: +8 high synergy (>=0.3), +6 commander staple (>=0.1), +4
popular pick (>0). Card limit: 60. If the structure changes at EDHREC's
end, this is where to look first.

**Scryfall oracle tag queries**
All `ScryfallService#cards_by_function` queries include
`-is:digital game:paper legal:commander`. The correct Scryfall oracle tag
for board wipes is `boardwipe` (not `wrath` — that was a bug).

**AI advisor**
`AiAdvisorService` model: `claude-sonnet-4-20250514`. API key in Rails
credentials under `anthropic.api_key`. `NlPromptParserService` uses the
same key and model.

**Thumbs-down blacklist guard**
`SuggestionFeedbacksController` calls `blacklist_card` BEFORE any API calls
on thumbs-down. Do not re-introduce optimistic DOM removal in
`thumb_controller.js#thumbDown` — it was previously destroying the form
before Turbo could submit it, silently swallowing the blacklist request.
Card removal must happen only via the Turbo Stream response.

**Commander pre-selection hidden input**
The hidden input that carries the selected commander's Scryfall UUID must
stay inside the `<form>` element. It was previously outside the form and
silently dropped on submission, losing the commander selection. Easy to
reintroduce when restructuring the new-deck view.

## Solid Cache / Solid Queue / Solid Cable migration hotfix

### Bug
Phase 20 crashed on every NL prompt submission in production:
```
PG::UndefinedTable: ERROR: relation "solid_cache_entries" does not exist
app/services/nl_prompt_parser_service.rb:15:in 'parse'
```
Solid Queue and Solid Cable would have failed similarly the moment any
background job or Action Cable message was sent.

### Root cause — Rails 8.1 multi-database footgun
The app uses a single physical PostgreSQL server for all four logical
databases (primary, cache, queue, cable). All four inherit from the same
`DATABASE_URL` in `config/database.yml`. Each has its own `migrations_paths`
(`db/migrate`, `db/cache_migrate`, `db/queue_migrate`, `db/cable_migrate`)
but they share a single physical schema.

The Rails install generators for Solid Cache, Solid Queue, and Solid Cable
only copy schema files (`db/cache_schema.rb`, `db/queue_schema.rb`,
`db/cable_schema.rb`) — they do NOT generate migration files or create the
migration directories. Schema files are only useful with `db:schema:load`.

Rails 8.1's `db:prepare` calls `initialize_database` for each configured
logical database. `initialize_database` checks whether `schema_migrations`
already exists on the connection to decide whether to load the schema. Because
the `schema_migrations` table is shared across all four connections (same
physical DB), once primary is set up the secondaries all see `schema_migrations`
as existing — so `db:prepare` marks them as "already initialised" and skips
schema loading for them entirely. With no migration files in the secondary
directories and schema loading skipped, none of the Solid tables were ever
created.

Local dev was unaffected: `development:` in `config/database.yml` is a
single-database config (no cache/queue/cable entries), so dev uses
`:memory_store` for cache and `:async` for queue. Tests use `:null_store`.
Neither path touches the `solid_cache_entries` table. CI was always green.

### Fix
- Added migration files in the three secondary directories:
  - `db/cache_migrate/20260508000001_create_solid_cache_entries.rb`
  - `db/queue_migrate/20260508000002_create_solid_queue_tables.rb`
  - `db/cable_migrate/20260508000003_create_solid_cable_messages.rb`
- Timestamps are sequential (000001/2/3) to avoid version collisions.
  Because all four logical databases share one `schema_migrations` table,
  migration version numbers must be globally unique across ALL migration
  directories. Using the same timestamp in multiple directories would cause
  later migrations to be silently skipped (they appear already-run in the
  shared `schema_migrations`).
- Updated `bin/docker-entrypoint` to run per-database migrate commands
  after `db:prepare`. `db:prepare` handles the primary database; the
  explicit `db:migrate:cache db:migrate:queue db:migrate:cable` commands
  guarantee the secondaries are always migrated. They are idempotent —
  no-ops when all migrations are current.

### Why both schema files AND migration files are needed
The schema files (`db/cache_schema.rb` etc.) are used only by `db:schema:load`
to set up a brand-new database from scratch. Migration files in the secondary
directories are used by `db:migrate` and `db:prepare`'s migration path for
incremental deploys. In this shared-physical-DB setup you need BOTH: schema
files for greenfield (though `db:prepare` will fall through to the migration
path anyway since schema loading is skipped), and migration files for every
deploy — including the first one, since schema loading is bypassed.

### What was verified locally
Created a throwaway database (`deck_sculptor_solidcache_test`) and ran:
```
RAILS_ENV=production DATABASE_URL=postgres://localhost/deck_sculptor_solidcache_test \
  bin/rails db:prepare
bin/rails db:migrate:cache db:migrate:queue db:migrate:cable
```
Confirmed all 13 tables were created (`solid_cache_entries`, 11
`solid_queue_*` tables, `solid_cable_messages`). Confirmed subsequent
runs of the explicit migrate commands are clean no-ops. Full suite:
596 examples, 0 failures.

## Known limitations

- NL prompt is single-shot; no conversational follow-up (e.g. "now narrow
  to under $5"). Each submit is independent.
- Fuzzy-role queries like "cheap removal" or "low CMC ramp" not supported —
  requires `all_roles` integration on the suggestion candidate pool.
- "Budget alternatives to X" requires price data (not currently stored).
- "Combos with X" returns combo partner cards only, not full combo chains
  (Commander Spellbook data exists; needs a richer result display).
- "Cards like X" uses subtype+CMC+keyword scoring; could be upgraded to
  shared oracle tag matching for better abstract similarity.
- `_deck_stats.html.erb:29` "Top Category" shows a functional label ("ramp",
  "draw") while the deck list groups by structural type. Deferred until a
  functional-role filter UI is added to the deck card list.
- Same deck open in two browser tabs shares the NL filter session state
  (`session[:nl_filter_specs][deck_id]`). Acceptable edge case given
  single-tab use pattern.

## Upcoming phases
- Phase 21: Suggestion filter polish, combos page improvements
  (target: post-MagicCon)
- Custom domain (decksculptor.com is squatted; revisit post-MagicCon)
- Email verification, password reset UI promotion, profile editing
  (intentionally out of scope for MagicCon)
