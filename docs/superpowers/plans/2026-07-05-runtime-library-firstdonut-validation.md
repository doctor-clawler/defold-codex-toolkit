# Runtime Library Firstdonut Validation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Validate `defold_helper` as a reusable Defold runtime library by extracting generic local leaderboard behavior and consuming it from `firstdonut`.

**Architecture:** `defold_helper` owns game-agnostic leaderboard row operations. `firstdonut` keeps an adapter named `main.outgame_leaderboard` so existing game code and tests keep their current interface while the reusable logic comes from the helper dependency.

**Tech Stack:** Defold library archive dependency, Lua modules, Lua unit tests, Python contract tests, existing Defold web build scripts.

## Global Constraints

- Do not move game-specific rules, character data, GUI node ownership, coins, ads, or platform policy into `defold_helper`.
- Do not overwrite unrelated dirty files in `firstdonut`, especially existing Google Play Console verification changes.
- Keep helper modules under the `defold_helper/` namespace.
- Consumers should depend on a pinned commit or release tag archive, not an unpinned branch archive.

---

### Task 1: Add Generic Helper Leaderboard Module

**Files:**
- Create: `defold_helper/local_leaderboard.lua`
- Modify: `tests/run_lua_tests.lua`
- Create: `tests/local_leaderboard_lua_test.lua`
- Modify: `docs/runtime-library.md`

**Interfaces:**
- Produces: `defold_helper.local_leaderboard.normalize(rows, options)`
- Produces: `defold_helper.local_leaderboard.record_run(existing_rows, run, options)`
- Produces: `defold_helper.local_leaderboard.copy_rows(rows, limit)`
- Produces: `defold_helper.local_leaderboard.format_time(seconds)`
- Produces: `defold_helper.local_leaderboard.format_rows(rows, options)`

- [ ] **Step 1: Write the failing Lua test**

Create `tests/local_leaderboard_lua_test.lua` with assertions for sorting, score rounding, best-score promotion, ignored empty runs, copy limits, and display formatting.

- [ ] **Step 2: Run the helper Lua tests and confirm the new test fails**

Run: `lua tests/run_lua_tests.lua`

Expected before implementation: require failure or missing function failure for `defold_helper.local_leaderboard`.

- [ ] **Step 3: Implement `defold_helper/local_leaderboard.lua`**

Implement the extracted generic behavior from `firstdonut/main/outgame_leaderboard.lua` without any `firstdonut` names.

- [ ] **Step 4: Register the test runner entry**

Update `tests/run_lua_tests.lua` so `local_leaderboard_lua_test.lua` runs with the existing helper Lua suite.

- [ ] **Step 5: Update runtime docs**

Add `defold_helper.local_leaderboard` to `docs/runtime-library.md` and describe the adapter pattern for project-specific row display.

- [ ] **Step 6: Verify helper**

Run:

```bash
lua tests/run_lua_tests.lua
python3 -m unittest discover -s tests -p 'test_*.py'
python3 -m json.tool .codex-plugin/plugin.json >/dev/null
```

Expected: all commands pass.

### Task 2: Consume Helper Leaderboard From Firstdonut

**Files:**
- Modify: `/Volumes/BigHugeMemory/works/firstdonut/game.project`
- Modify: `/Volumes/BigHugeMemory/works/firstdonut/main/outgame_leaderboard.lua`
- Modify: `/Volumes/BigHugeMemory/works/firstdonut/tests/outgame_leaderboard_lua_test.lua` if package-path setup is needed
- Modify: `/Volumes/BigHugeMemory/works/firstdonut/tests/game_state_persistence_lua_test.lua` if package-path setup is needed

**Interfaces:**
- Consumes: `defold_helper.local_leaderboard`
- Preserves: `main.outgame_leaderboard.normalize`
- Preserves: `main.outgame_leaderboard.record_run`
- Preserves: `main.outgame_leaderboard.copy_rows`
- Preserves: `main.outgame_leaderboard.format_time`
- Preserves: `main.outgame_leaderboard.format_rows`

- [ ] **Step 1: Add a failing wiring assertion**

Extend `tests/outgame_leaderboard_lua_test.lua` to assert that `main.outgame_leaderboard` can require the helper-backed implementation.

- [ ] **Step 2: Add the helper archive dependency**

Add the pinned helper archive URL to `[project]` dependencies in `game.project`.

- [ ] **Step 3: Replace local leaderboard internals with an adapter**

Modify `main/outgame_leaderboard.lua` to require `defold_helper.local_leaderboard` and delegate all existing public functions.

- [ ] **Step 4: Keep project defaults local**

Ensure `DEFAULT_LIMIT = 10` and `DEFAULT_CHARACTER_ID = "classic"` remain in `firstdonut/main/outgame_leaderboard.lua`.

- [ ] **Step 5: Verify firstdonut Lua tests**

Run:

```bash
lua tests/outgame_leaderboard_lua_test.lua
lua tests/game_state_persistence_lua_test.lua
```

Expected: both pass.

### Task 3: End-to-End Consumer Verification

**Files:**
- Read: `/Volumes/BigHugeMemory/works/firstdonut/scripts/build_web.sh` or nearest existing web build script
- Read: `/Volumes/BigHugeMemory/works/firstdonut/tests/gameplay_feature_contract_test.py`

**Interfaces:**
- Consumes: firstdonut existing contract tests and web build flow
- Produces: evidence that the helper archive resolves in a real Defold build

- [ ] **Step 1: Run firstdonut contract tests**

Run:

```bash
python3 -m pytest tests/gameplay_feature_contract_test.py
```

If pytest is unavailable, use the repo's existing Python test invocation.

- [ ] **Step 2: Run the web build**

Run the existing `firstdonut` web build script. If no wrapper exists, inspect scripts before calling `bob.jar` directly.

- [ ] **Step 3: Confirm dependency resolution**

Confirm the build log shows the helper archive URL resolving successfully and no duplicate module errors.

### Task 4: Commit And Push

**Files:**
- Helper repo changes from Task 1
- Firstdonut repo changes from Task 2 and Task 3 docs/test adjustments

**Interfaces:**
- Produces: one helper commit and one firstdonut commit
- Produces: pushed branches unless remote rejects

- [ ] **Step 1: Review helper status**

Run: `git status --short` in `/Volumes/BigHugeMemory/works/defold-helper-marketplace`

- [ ] **Step 2: Commit helper changes**

Commit message:

```bash
git commit -m "feat: add reusable local leaderboard runtime"
```

- [ ] **Step 3: Push helper changes**

Run: `git push`

- [ ] **Step 4: Review firstdonut status**

Run: `git status --short` in `/Volumes/BigHugeMemory/works/firstdonut`

Confirm unrelated modified files are not staged.

- [ ] **Step 5: Commit firstdonut changes**

Commit message:

```bash
git commit -m "refactor: consume defold helper leaderboard"
```

- [ ] **Step 6: Push firstdonut changes**

Run: `git push`

