# Defold Runtime Library Firstdonut Validation Design

**Goal:** Prove that `defold_helper` can be shipped as a reusable Defold runtime library by moving one more real outgame feature into the helper and consuming it from `firstdonut`.

**Recommended approach:** Add a generic `defold_helper.local_leaderboard` module and keep `firstdonut`-specific character names, save-file policy, and UI text in `firstdonut`.

## Current Shape

`defold_helper` already owns reusable score/runtime layers:

- `defold_helper.score_records`
- `defold_helper.score_ui`
- `defold_helper.game_over_ui`
- `defold_helper.gameplay_layer`

`blocktris` consumes these through a pinned GitHub archive dependency and keeps local wrappers for height-specific naming.

`firstdonut` already has a local leaderboard module in `main/outgame_leaderboard.lua`. That module mixes two responsibilities:

- generic leaderboard operations: normalize rows, insert a run, sort by score and time, copy rows, format time
- project policy: default character id, character-name display, empty-row text

## Architecture

Move only the generic operations into `defold_helper.local_leaderboard`. Leave all game rules and display policy in the consuming project.

`firstdonut/main/outgame_leaderboard.lua` becomes an adapter that delegates to `defold_helper.local_leaderboard` and exposes the same public functions it already has. This keeps existing `game_state.lua`, `character_select.gui_script`, and tests stable.

The helper module must not know about donuts, characters, coins, ads, remote backends, GUI nodes, or Defold collection flow.

## Interfaces

`defold_helper.local_leaderboard` should provide:

- `normalize(rows, options) -> rows`
- `record_run(existing_rows, run, options) -> { rows, best_score, recorded }`
- `copy_rows(rows, limit) -> rows`
- `format_time(seconds) -> "MM:SS"`
- `format_rows(rows, options) -> string[]`

Options should support:

- `limit`
- `default_character_id`
- `empty_text`
- `character_name(character_id)`

Sorting policy:

- higher score first
- if score ties, longer time first
- invalid rows are ignored
- row count is capped by `limit`

## Validation

Helper validation:

- Lua unit test for normalize, record, empty-run, copy, and formatting behavior
- Python metadata tests still pass
- docs mention `local_leaderboard`

Firstdonut validation:

- `game.project` depends on the helper archive
- `main/outgame_leaderboard.lua` is a thin adapter over `defold_helper.local_leaderboard`
- existing Lua tests pass without behavior changes
- existing Python contract tests pass
- web build resolves the helper dependency successfully

## Release Boundary

After helper and firstdonut tests pass, the helper is technically reusable by other Defold projects. For a stable distribution surface, create a release tag such as `v0.3.0` or `v0.4.0` and have consumers depend on the tag archive rather than a moving branch.

