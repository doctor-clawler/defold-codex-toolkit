# Defold Helper Runtime Library

`defold-codex-toolkit` also ships a small Defold library under the collision-resistant `defold_helper/` namespace. The helper repo is the source of truth for these runtime modules:

- `defold_helper.score_records`
- `defold_helper.score_ui`
- `defold_helper.game_over_ui`
- `defold_helper.gameplay_layer`
- `defold_helper.localization`

## Defold Adoption

The library project exposes only `defold_helper` through `game.project`:

```ini
[library]
include_dirs = defold_helper
```

In a consuming Defold project, add a pinned library archive URL to the `[project]` dependencies list:

```ini
[project]
dependencies#0 = https://github.com/doctor-clawler/defold-codex-toolkit/archive/<commit-or-tag>.zip
```

After changing dependencies, run `Project > Fetch Libraries` in the Defold editor. Defold will expose the shared folder so project code can use direct namespaced requires:

```lua
local score_records = require("defold_helper.score_records")
local score_ui = require("defold_helper.score_ui")
```

Use a release tag or pinned commit archive for production projects. A branch archive is useful for quick smoke checks but can change underneath a consumer.

## Adapter Pattern

Keep project-specific naming and game rules in the consumer project. For example, a tower-height game can wrap generic score records with local field names:

```lua
local score_records = require("defold_helper.score_records")

local HEIGHT_FIELDS = {
  last_score = "last_height_m",
  best_score = "best_height_m",
  total_score = "total_height_m",
  best_combo = "best_combo",
}

local state = score_records.load({
  sys = sys,
  app_name = "stack-rush",
  file_name = "height_records",
  fields = HEIGHT_FIELDS,
})
```

## Localization Tables

`defold_helper.localization` loads simple CSV localization tables with a `key` column and one column per language. Optional metadata columns such as `comment` or columns starting with `#` are ignored.

```csv
key,en,ko,comment
ui.title,Mini Survivor,미니 서바이버,shown on title screen
ui.greeting,"Hello, {name}","안녕, {name}",supports placeholders
```

In a Defold game, list the CSV file as a custom resource and load it through a small project-local adapter:

```lua
local localization = require("defold_helper.localization")

local bundle = localization.from_resource("/assets/localization.csv", {
  sys = sys,
  default_language = "en",
  fallback_language = "en",
})

print(bundle:text("ui.greeting", { name = "Ada" }))
print(bundle:text("ui.title", "ko"))
```

The helper intentionally does not own a global language setting for the whole game. Keep save data, settings UI, and language switching policy in the consuming project.

The helper modules should not depend on a specific game name, score unit, GUI file, leaderboard backend, or advertising provider.
