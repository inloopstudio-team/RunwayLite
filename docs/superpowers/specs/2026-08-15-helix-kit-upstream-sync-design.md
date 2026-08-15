# Upstream Sync: helix_kit → talkyform-codebase

**Date:** 2026-08-15  
**Approach:** Git remote + cherry-pick (Option A)

## Context

talkyform-codebase is a file-copy fork of helix_kit (no shared git history). The fork was taken at helix_kit commit `634d006` (2026-08-12). Three upstream commits have landed since:

| Order | Hash | Message | Conflict Risk |
|-------|------|---------|--------------|
| 1 | `747f1884` | Refresh latest AI models | Medium — touches `model_selection.rb` |
| 2 | `41b9ea32` | Make backup restores resilient | Low — new files + unchanged shared file |
| 3 | `0f0448b5` | Price Gemini 3.7 Flash and Grok 4.6 usage | Low — isolated service file |

## Implementation Steps

### 1. Register upstream remote
```bash
git remote add helix_kit /Users/sneha/sne_workspace/talkyform/helix_kit
git fetch helix_kit
```

### 2. Cherry-pick in chronological order

```bash
git cherry-pick 747f1884ead8117f7efae1b0e2e08eed92f6a47a
# resolve model_selection.rb if needed, then:
git cherry-pick 41b9ea32ca0c5ff0f2f05e40af3ea1d48b721ab7
git cherry-pick 0f0448b55df8baa1a98a38215565120cf606aefa
```

**Conflict guide for `model_selection.rb`:**
- Upstream changed: the `MODELS` constant array (model catalog entries, top of file)
- talkyform added: `model_id=`, `provider=`, `assume_model_exists=` setter methods (bottom of file)
- Resolution: keep both — accept all upstream MODELS changes AND preserve talkyform's setter methods

### 3. Verify

```bash
RUST_LOG=warn bundle exec rails test test/models/
```

Expected: no regression beyond the 9 pre-existing failures.

### 4. Cleanup

```bash
git remote remove helix_kit
```

## Success Criteria

- All 3 commits present in `git log`
- `bundle exec rails test test/models/` passes with same or fewer failures than before sync
- `model_selection.rb` contains both updated model catalog AND talkyform's setter methods
