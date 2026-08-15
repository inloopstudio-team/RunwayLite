# Fork Import Design: talkyform-codebase → RunwayLite

**Date:** 2026-08-15  
**Author:** Sneha  
**Status:** Approved

## Goal

Import all 8 commits made today in `/Users/sneha/sne_workspace/talkyform/talkyform-codebase` (the fork) into the current project at `/Users/sneha/sne_workspace/talkyform/RunwayLite`. The fork contains comprehensive libSQL/SQLite compatibility fixes and several application-level features missing from RunwayLite.

## Background

The fork diverged from RunwayLite and accumulated fixes for libsql_activerecord failures. RunwayLite currently has a minimal 5-fix libSQL patch; the fork has a comprehensive 14-fix patch covering transactions, unicode encoding, boolean conversion, foreign key pragma control, and full SQLite capability declarations.

## Approach: Git Remote + Cherry-Pick

Add the fork as a local git remote, fetch, and cherry-pick all 8 commits in chronological order. This preserves original commit messages and authorship, and surfaces conflicts surgically per commit.

## Commits to Import (Chronological Order)

| # | SHA | Message | Risk |
|---|-----|---------|------|
| 1 | `006670f4` | Fix dev environment setup for libSQL/SQLite compatibility | High (28 files, Gemfile) |
| 2 | `da277bc1` | Fix libSQL/SQLite compatibility for test suite | High (45 files) |
| 3 | `d0006a19` | Fix unicode corruption in libsql string results | Low (1 file) |
| 4 | `c77c157e` | Refresh latest AI models | Low |
| 5 | `c74bb39d` | Make backup restores resilient | Medium |
| 6 | `344d6bd5` | Price Gemini 3.7 Flash and Grok 4.6 usage | Low |
| 7 | `a9ce1a69` | Post-sync fixes: missing model catalog entries and constants | Low |
| 8 | `20ad667f` | Add upstream sync design spec | Low |

## Implementation Steps

### 1. Add Remote & Fetch
```bash
git remote add fork /Users/sneha/sne_workspace/talkyform/talkyform-codebase
git fetch fork
```

### 2. Cherry-Pick Each Commit
```bash
git cherry-pick 006670f4
# resolve conflicts if any, then: git cherry-pick --continue
git cherry-pick da277bc1
# resolve conflicts if any
git cherry-pick d0006a19
git cherry-pick c77c157e
git cherry-pick c74bb39d
git cherry-pick 344d6bd5
git cherry-pick a9ce1a69
git cherry-pick 20ad667f
```

### 3. Conflict Resolution Strategy

**For libSQL/SQLite commits (commits 1–3):**
- Prefer fork's version for `config/initializers/libsql_rails81_compat.rb` — the comprehensive 14-fix patch replaces RunwayLite's 5-fix version
- Prefer fork's version for `config/database.yml` pool settings and test configuration
- For `Gemfile`: keep RunwayLite's GitHub fork references for `ruby_llm` and `fosm-rails`; take fork's libsql-related gem changes
- Accept fork's `lib/tasks/libsql_test_db.rake` (new file, no conflict)

**For application commits (commits 4–8):**
- Accept fork changes as-is; these are net-new files or isolated model changes with low conflict probability

### 4. Cleanup
```bash
git remote remove fork
```

### 5. Verify
```bash
rails test
```
All tests must pass before the import is considered complete.

## Key Files Affected

- `config/initializers/libsql_rails81_compat.rb` — comprehensive libSQL patch (primary deliverable)
- `config/database.yml` — pool settings for test environment
- `Gemfile` / `Gemfile.lock` — gem dependency changes
- `lib/tasks/libsql_test_db.rake` — new task overriding db:test:prepare
- `app/models/chat/model_selection.rb` — AI model catalog updates
- `app/services/agent_runtime_interaction_cost.rb` — new cost tracking service
- `app/services/backup/local_agent_runtime_image.rb` — new backup service
- `db/migrate/` — new migrations from the fork
- `db/schema.rb` — schema changes

## Success Criteria

- All 8 commits land cleanly on the RunwayLite master branch
- `rails test` passes after import
- `config/initializers/libsql_rails81_compat.rb` contains the full 14-fix comprehensive patch
- No regression in existing RunwayLite functionality
