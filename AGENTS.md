# Repository Guidelines

## Project Structure & Module Organization
RunwayLite couples Rails 8 and Svelte 5 through Inertia. Domain models live in `app/models`, controllers in `app/controllers`, and jobs in `app/jobs`. Frontend primitives and patterns stay under `app/frontend`, with styles in `app/frontend/styles`. Configuration belongs inside `config`, and `docs/overview.md` points to deeper architectural guides.

## Build, Test, and Development Commands
Run `bin/dev` to launch Rails, Vite, and the Solid* services on http://localhost:3100. Keep schemas up to date with `bin/rails db:prepare` and migrate via `bin/rails db:migrate && bin/rails db:schema:dump`. Frontend tooling runs through Yarn: `yarn install`, `yarn test:unit` (Vitest), `yarn test` (Playwright E2E). Use `bin/rails test` or narrow scope, e.g. `bin/rails test test/models/user_test.rb`.

## Coding Style & Naming Conventions
Write as though you are DHH shipping code into Rails core: choose the boring, conventional solution, prefer readability over cleverness, and rely on Rails helpers before building abstractions. Ruby follows RuboCop (`bin/rubocop`), two-space indent, snake_case methods, PascalCase classes. Keep models lean; push orchestration into POROs under `app/lib` or concerns. Svelte components use kebab-case filenames (`user-menu.svelte`), camelCase props, and Tailwind utility classes; format with `yarn format` / `yarn format:check`.

## DHH Mode Checklist
1. Ask “How would Rails solve this today?” before adding gems or custom JS.
2. Pretend future maintainers are Rails core reviewers—ship code they would merge.
3. If a solution feels clever, rewrite it straighter and document any intentional divergence from convention.

## Testing Guidelines
Minitest lives in `test/`; mirror Rails naming such as `accounts_controller_test.rb` and lean on fixtures in `test/fixtures`. Co-locate Vitest specs beside Svelte sources as `*.test.ts`. Playwright journeys reside in `playwright/tests`; always run them via the provided scripts and never touch the dev database destructively. Expand coverage with each feature and share factories instead of hard-coded records.

## Commit & Pull Request Guidelines
Use short, imperative commit subjects (<72 chars) like `Add chats index pagination`, grouping related work. Reference issues in the body when useful. PRs need a problem summary, UI screenshots when visuals change, and explicit notes on migrations or secrets. Run `bin/rubocop`, `yarn format:check`, `bin/rails test`, and `yarn test` before requesting review.

## Environment & Safety
The shared development database is long-lived—never run `rails db:drop`, `db:reset`, or mass `destroy_all`. Leave the existing `bin/dev` process running instead of killing its PID in `tmp/pids`. Manage secrets with `config/credentials.yml.enc` and consult `docs/` before altering infrastructure or dependencies.

---

<!-- fosm:agent-instructions -->
## FOSM (fosm-rails)

This project uses `fosm-rails` — a Finite Object State Machine engine for declarative model lifecycle management. For the full design philosophy, architecture reference, and contributing guidelines, read:

`tmp/fosm-rails/AGENTS.md` (synced from the gem at boot)

### What FOSM is

FOSM binds a state machine directly to a business entity. The `lifecycle` block in a model is the single source of truth for valid states, transitions, guards, side effects, and RBAC access control. Nothing else governs state change.

### The one rule: `fire!` is the only mutation path

**Never** change state via `update(state: "active")` or direct attribute assignment. The only valid path is:

```ruby
record.fire!(:event_name, actor: current_user)
```

`fire!` enforces guards, checks RBAC, writes the immutable transition log, runs side effects, and enqueues webhooks — all atomically. Bypassing it breaks the audit trail, disables guard enforcement, and makes AI agents unbounded.

### FOSM models in this app

**`Account`** — `app/models/account.rb`
- States: `active` (initial) ↔ `disabled`
- Events: `disable`, `enable`
- Side effects: syncs `disabled_at` column for backward compatibility
- Scopes use the `state` column

**`Membership`** — `app/models/membership.rb`
- States: `pending` (initial) → `active`
- Events: `confirm`
- Side effect: sets `confirmed_at`, clears confirmation token
- The `Confirmable` concern delegates to `fire!(:confirm)` — do not call `update(confirmed_at:)` directly
- `skip_confirmation` sets both `confirmed_at` and `state = "active"` on create

### Guards are pure functions

A guard block receives the record and returns `true` or `false`. It must have **no side effects** — `can_fire?` calls guards to check availability without triggering anything. A guard with side effects breaks the admin UI and agent introspection.

### Terminal states are permanent

`terminal: true` means no event can fire from that state. To "undo" a terminal state, add a compensating event (e.g., `reopen` → back to an earlier state). Do not remove the `terminal:` constraint.

### Database / connection pools — IMPORTANT

RunwayLite uses a **dedicated `fosm` database role** in `database.yml` (a separate SQLite file in development). `Fosm::ApplicationRecord` detects this and connects to it automatically.

**Do NOT** add a `primary:` database role for FOSM. `primary` is the default role Rails assigns to every `database.yml` entry — doing so creates a redundant pool on the same database and causes a deterministic cross-pool deadlock whenever a `Fosm::*` model is saved inside a transaction that also touches the main pool (e.g., ActiveStorage callbacks).

If you need to change database configuration, read the "Database configuration and connection pools" section in `tmp/fosm-rails/AGENTS.md` first.

### FOSM file locations in this app

| Path | Purpose |
|---|---|
| `app/models/account.rb` | Account lifecycle (include Fosm::Lifecycle) |
| `app/models/membership.rb` | Membership lifecycle (include Fosm::Lifecycle) |
| `app/models/concerns/confirmable.rb` | Delegates confirmation to `fire!(:confirm)` |
| `db/fosm_migrate/` | FOSM-specific migrations (separate from main schema) |
| `config/initializers/fosm.rb` | FOSM configuration (transition_log_strategy, etc.) |

### Adding a new FOSM-managed model

```bash
rails generate fosm:app invoice \
  --fields customer:string amount:decimal \
  --states draft,sent,paid,cancelled \
  --access authenticate_user!
```

Then fill in events in `app/models/fosm/invoice.rb` and run `rails db:migrate`.

### Key references

- Full FOSM AGENTS.md: `tmp/fosm-rails/AGENTS.md`
- FOSM paper: [parolkar.com/fosm](https://parolkar.com/fosm)
- fosm-rails gem: [github.com/inloopstudio/fosm-rails](https://github.com/inloopstudio/fosm-rails)
