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
- Phase 13 complete and merged — UpgradeFinder tuning, upgrade card images, continued polish
- Phase 14 complete and merged — CardCategorizer rewrite (oracle text based functional categories), clickable category pages, MDFC secondary_categories support, backfill migration
- Phase 15 complete and merged — deck card list type grouping, suggestion filters, EDHREC scoring boost, N+1 fixes
- Phase 16 complete and merged — Railway deployment, mobile responsive fixes, healthcheck route
- Phase 16 hotfix complete and merged — fix Railway healthcheck (remove shell-operator startCommand, remove duplicate puma bind, bypass Thruster)
- Phase 17 complete and merged — Rails 8 authentication, Google SSO, anonymous deck claim flow
- Phase 17 hotfix 1 (manual) — production migrations had to be run manually via railway ssh after deploy because Rails 8 entrypoint did not run db:prepare on container start
- Phase 17 hotfix 2 complete and merged — disable Turbo on Google signin button so OAuth POST does a top-level redirect instead of XHR (Turbo's default fetch triggered a CORS preflight that Google rejected with 405)
- Phase 18 complete and merged — card image hover-zoom on laptop, tap-to-modal on mobile
- Phase 18 hotfix: fix add-card-from-search not updating deck card list (deck_cards#create previously returned a suggestions-page-only Turbo Stream that no-op'd on the deck show page; now appends the new card row AND removes any matching suggestion card)
- Phase 18 hotfix: Building Toward panel now counts cards in all roles they fulfill (CardCategorizer#all_roles + RatioAnalyzer re-evaluates from stored oracle text) — creatures that also ramp/draw/remove now count toward both the Creature bucket and the functional bucket
- Phase 19 complete — fix deck list type grouping in Turbo Stream re-renders (cards_by_type used consistently across all paths)
- Phase 20 complete — natural language prompt search on suggestions page
- Phase 20 hotfix complete — Solid Cache/Queue/Cable migrations missing in production; Phase 20 feature was production-broken from merge until this hotfix shipped
- Live at https://web-production-aefc3.up.railway.app
- 596 examples, 0 failures
- CI green
- Currently on branch: `hotfix-solid-cache-migration`

## What was built in Phase 17
- Rails 8 built-in authentication as the foundation (User, Session,
  SessionsController, PasswordsController, Authentication concern)
- omniauth-google-oauth2 layered on top for Google SSO
- Google SSO as the primary signin path, email/password as fallback
- User model: email (unique, indexed), password_digest (nullable for
  SSO-only users), google_uid (unique, indexed, nullable)
- Session model: belongs_to user, stores ip_address and user_agent
- Deck model: belongs_to :user (optional), plus anonymous_session_token
  column for pre-auth deck tracking
- Anonymous deck claim flow: signed cookie tracks pre-auth session, on
  signup/signin all decks with matching token get reassigned to new user
- OmniauthCallbacksController handles /auth/google_oauth2/callback,
  creates user on first signin, links google_uid on subsequent signins
- RegistrationsController for email/password signup
- Authorization: decks scoped to current_user OR anonymous_session_token
  in DecksController; unauthorized access redirects to signin
- Signin/signup views with prominent "Continue with Google" button and
  email/password form below
- Nav partial shows signin link or user email + signout link
- ENV vars required: GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET
- OAuth redirect URIs configured for both Railway prod and localhost dev
- Hotfix 1: Rails 8's docker-entrypoint did not run db:prepare on
  server start, so production booted with no users/sessions/decks
  ownership tables. Fix: ran `bin/rails db:migrate` manually inside
  the Railway container via `railway ssh`. The entrypoint was later
  updated in the Phase 20 Solid Cache hotfix to run db:prepare plus
  explicit per-database migrate commands on every deploy.
- Hotfix 2: Turbo Drive intercepted the "Continue with Google"
  button_to form submission and tried to fetch it via XHR, which
  triggered a CORS preflight that Google's OAuth endpoint rejected
  with 405 Method Not Allowed. Fix: added `data: { turbo: false }`
  to the button_to in `app/views/shared/_google_signin_button.html.erb`
  so the browser does a normal top-level POST that OmniAuth can
  redirect from.
- Polish: show/hide password toggle on signin and signup forms via
  a small Stimulus controller (password_visibility_controller.js).
  Eye icon swaps to eye-slash when password is visible. 44px tap
  targets for mobile.

## What was built in Phase 16
- Deployment config: Procfile, railway.toml, config/database.yml reads
  DATABASE_URL in production
- Mobile responsive fixes across the app: 44px minimum tap targets on
  all interactive elements, flex-wrap on nav so it doesn't overflow on
  narrow viewports, responsive deck card grid
- /up healthcheck route (inline proc returning 200 "ok")
- active_storage.variant_processor set to :disabled in production to
  avoid libvips boot issue on Railway
- Puma config binds via `port ENV.fetch("PORT", 3000)` — Puma's port
  directive already binds to 0.0.0.0 by default
- Dockerfile bypasses Thruster so Puma serves directly on Railway's
  dynamic $PORT (Thruster's port 80 was incompatible with Railway's
  healthcheck)
- railway.toml has no startCommand or builder keys — Railway uses the
  Dockerfile's ENTRYPOINT (/rails/bin/docker-entrypoint runs db:prepare)
  and CMD directly
- Live URL: https://web-production-aefc3.up.railway.app

## What was built in Phase 15
- Deck card list now groups by card TYPE (Creature, Instant, Sorcery,
  Artifact, Enchantment, Planeswalker, Land) not functional category
- Deck::TYPE_LABELS and DISPLAY_ORDER constants — land priority in
  bucketing ensures Enchantment Lands (e.g. Urza's Saga) show under Land
- Land section header shows "Land · N cards · M MDFC" format
- RatioAnalyzer#compute_actuals now counts secondary_categories so MDFC
  lands count toward land total in Building Toward panel
- Fixed N+1 queries in SuggestionEngine: memoized memo_creature_count,
  memo_mana_curve, memo_combo_deck_names
- Fixed IntentEngine pool labels to match filter pill values:
  "Staple" → "ramp", "Card Draw" → "draw"
- Added board_wipe (boardwipe), removal, land (utility-land) as
  always-fetched staple pools
- WIN_CONDITION_POOLS updated: "Removal" → "removal", "Board Wipes" →
  "board_wipe"
- EDHREC scoring boosted: +8/+6/+4 (was +3/+2/+1) so synergy cards
  dominate suggestions
- EDHREC card limit raised from 20 to 60
- Other bonuses rebalanced: keyword +2, curve +1, category +1, theme
  cap +2
- Fixed boardwipe oracle tag: "wrath" → "boardwipe" (correct Scryfall tag)
- 502 examples, 0 failures

## What was built in Phase 14
- CardCategorizer rewritten with oracle text priority: land → ramp → draw
  → board_wipe → removal → tutor → protection → creature → type fallback
- 42 spec examples covering all categories and edge cases
- secondary_categories string column on DeckCard for MDFC/split card support
- CardCategorizer#categories (plural) returns all applicable categories
  by iterating card_faces
- Backfill migration using CardCache → Scryfall fallback
- Clickable Building Toward panel rows → /decks/:id/cards/:category pages
  with full card image grid
- Human-readable category labels in deck card list headers
- Land header shows MDFC count

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
- DeckCard — a card in a deck with category, cmc, color_identity (string)
- CardCache — local Scryfall response cache, 7-day TTL
- SuggestionFeedback — per-deck per-card thumbs up/down signal, unique on
  [deck_id, scryfall_id]
- Card — scryfall_id (unique), name, type_line, oracle_text, image_uri, cmc,
  color_identity; find_or_create_from_scryfall, to_scryfall_hash

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

## Railway deployment (Phase 16)
Live URL: https://web-production-aefc3.up.railway.app
Required environment variables in Railway dashboard:
- `RAILS_MASTER_KEY` — contents of config/master.key
- `DATABASE_URL` — provided automatically by Railway PostgreSQL plugin
- `ANTHROPIC_API_KEY` — your Anthropic API key for the AI advisor
- `RAILS_ENV=production`
- `GOOGLE_CLIENT_ID` — from Google Cloud Console OAuth client (Phase 17)
- `GOOGLE_CLIENT_SECRET` — from Google Cloud Console OAuth client (Phase 17)

Deployment notes (learned the hard way in Phase 16 hotfix):
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

## Google OAuth setup (Phase 17)
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

## What was built in Phase 18 (in progress)
- Card image hover-zoom on laptop: hovering a card thumbnail in the
  deck list expands to a full-size overlay via card-magnify Stimulus
  controller
- Tap-to-modal on mobile: same controller shows a modal on tap for
  touch devices, replacing the hover behavior that doesn't exist on
  mobile
- Mobile-first header layout on deck show page — buttons wrap and
  stack correctly on narrow viewports
- Fixed silent failure when adding a card via the search dropdown on
  the deck show page. DeckCardsController#create now returns a Turbo
  Stream that updates the full deck card list (turbo_stream.update
  "deck_card_list") AND removes any matching suggestion card
  (turbo_stream.remove "suggestion-{id}"). The same response works on
  both the deck show page and the suggestions page — the irrelevant
  action is a no-op on whichever page doesn't have the matching
  target. Also added @deck.deck_cards.reload in the RecordNotUnique
  rescue path to clear the unsaved card from the association cache
  before re-rendering the list.
- Fixed Building Toward panel undercounting categories. Added
  CardCategorizer#all_roles which collects every functional role a
  card fulfills (ramp, draw, removal, board_wipe, tutor, protection,
  creature) rather than returning the single waterfall winner. Lands
  return ["land"] only (no false ramp from {T}: Add {X} text).
  RatioAnalyzer#compute_actuals now re-evaluates each DeckCard via
  all_roles from stored type_line, oracle_text, and raw_data — no
  migration needed, retroactively correct for all existing decks.
  The deck list grouping (cards_by_type) is untouched and continues
  to use primary category only so cards don't appear in multiple
  deck list sections.

## What was built in Phase 19
- Fixed deck list type grouping regression in all Turbo Stream re-render
  paths. On first load, DecksController#show correctly called
  @deck.cards_by_type. But three paths that re-render the
  _deck_card_list partial via Turbo Stream were still passing
  @deck.cards_by_category (functional roles), causing the list to flip
  to Ramp / Removal / Draw section headers after any card add, quantity
  update, or bulk import:
    - DeckCardsController#create success and RecordNotUnique rescue paths
    - deck_cards/update.turbo_stream.erb
    - DeckImportsController#create
  Fix: all three now pass @deck.cards_by_type. cards_by_category and
  all_roles are untouched — the analysis page and Building Toward panel
  continue to use functional categories exactly as before.
- Contract tests added using Bloom Tender (Creature that fulfills ramp
  role) as the canonical case: the Turbo Stream response for create,
  update, and import must render a "Creature" section header and must
  not render a "Ramp" section header.
- Known follow-up: _deck_stats.html.erb:29 shows a "Top Category"
  quick stat that calls deck.cards_by_category directly, so the show
  page displays a functional label ("ramp", "draw") in that one stat
  while the card list groups by structural type. This inconsistency is
  intentional for now — a future phase will add a functional-role
  filter UI to the deck card list (the right home for all_roles data),
  at which point the Top Category stat can be reconsidered or removed.

## What was built in Phase 20
- Natural language prompt bar above the filter pills on the suggestions
  page. User types "show me only elves", "cards like Sol Ring", or
  "cards that combo with Thassa's Oracle" and hits Enter or Search.
- NlPromptParserService — calls Claude API (claude-sonnet-4-20250514,
  max 256 tokens) with a structured system prompt. Returns ONLY JSON
  (no prose). Parsed FilterSpec hash keys: filter_type (type/similarity/
  combo), types, subtypes, colors, max_cmc, min_cmc, keywords,
  reference_card. Caches by SHA256(prompt.downcase), 5-minute TTL via
  Solid Cache. On API error or JSON parse failure returns nil (no filter
  applied). Reuses same HTTParty + credentials pattern as AiAdvisorService.
- SuggestionFilter — applies FilterSpec to the already-scored suggestion
  pool (plain Ruby, no AR queries, no API calls for type filter):
  - "type" filter: AND-chains all present spec fields (subtypes, types,
    colors, CMC range, keywords) against card["type_line"] /
    card["color_identity"] / card["cmc"] / card["keywords"]
  - "similarity" filter: score-based with threshold 2 of 4 signals
    (subtype overlap, keyword overlap, CMC ±2, color overlap). Tests
    pinned with Sol Ring, Lightning Bolt, and Rhystic Study as canonical
    cases. One Scryfall lookup for the reference card (cached).
  - "combo" filter: ComboFinderService.find_combos([reference_card])
    → keeps suggestion-pool cards that appear as combo partners. Reuses
    existing Commander Spellbook integration with no new infrastructure.
  - nil spec → returns all suggestions unchanged
- DecksController#filter_suggestions (POST member route):
  - Empty prompt: clears session key, returns full unfiltered pool
  - Non-empty: parses → filters → responds with Turbo Stream updating
    #suggestions-grid + replacing/removing #load-more-btn
  - Session key scoped by deck_id: session[:nl_filter_specs][deck_id].
    Prevents filter from leaking to other decks in the same tab session.
    Known acceptable edge case: same deck open in two tabs shares state.
- DecksController#suggestions GET: clears the session key for this deck,
  so a fresh page load always starts unfiltered.
- DecksController#more_suggestions: reads session filter spec and applies
  it via SuggestionFilter so pagination respects an active NL filter.
- _suggestions_grid_content.html.erb partial extracted so both the full
  page render and Turbo Stream turbo_stream.update share the same template.
- nl_prompt_controller.js Stimulus controller: form, input, spinner,
  clearBtn, submitBtn targets. Listens to turbo:submit-start/end on the
  form target for loading state. clear() empties input and requestSubmit()s.
  updateClearVisibility() shows/hides × button. No querySelector by class;
  all DOM access via data-* targets. Single responsibility. 1-line comment
  notes no JS test suite yet; written to be testable when one is added.
- Filter composition: NL filter narrows pool server-side; existing
  category pills and name search (Stimulus) apply on top client-side.
  Logical AND. The two layers don't interfere.
- 596 examples, 0 failures
- NOTE: Phase 20 was production-broken from the moment of merge until
  the Solid Cache hotfix below shipped. Every NL prompt submission
  crashed with PG::UndefinedTable: relation "solid_cache_entries" does
  not exist. Local dev and CI were unaffected (dev uses :memory_store,
  tests use :null_store). See hotfix section below for root cause.

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

## Upcoming phases
- Phase 21: Suggestion filter polish, combos page improvements
  (target: post-MagicCon)
- Custom domain (decksculptor.com is squatted; revisit post-MagicCon)
- Email verification, password reset UI promotion, profile editing
  (intentionally out of scope for MagicCon)

## Phase 20 NL prompt — out of scope for v1 (future work)
- Saved prompts / prompt history
- "Cheap removal" / "low CMC ramp" fuzzy-role queries (would need
  all_roles integration on the suggestion candidate pool — separate phase)
- "Budget alternatives to X" (price data not currently stored)
- Conversational follow-up ("now narrow to under $5") — v1 is single-shot
- "Combos with X" returning full combo chains rather than partner cards
  only (Commander Spellbook data already available; just needs a richer
  result display)
- Upgrading "cards like X" from subtype+CMC+keyword scoring (Option 1)
  to shared oracle tag matching (Option 2) for better abstract similarity
