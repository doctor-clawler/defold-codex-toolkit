# Defold Helper Runtime Library

`defold-codex-toolkit` also ships a small Defold library under the collision-resistant `defold_helper/` namespace. The helper repo is the source of truth for these runtime modules:

- `defold_helper.score_records`
- `defold_helper.score_ui`
- `defold_helper.game_over_ui`
- `defold_helper.gameplay_layer`
- `defold_helper.local_leaderboard`
- `defold_helper.localization`
- `defold_helper.privacy_modal`
- `defold_helper.scroll`

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
local local_leaderboard = require("defold_helper.local_leaderboard")
local privacy_modal = require("defold_helper.privacy_modal")
local scroll = require("defold_helper.scroll")
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

## Privacy Modal Adapter

`defold_helper.privacy_modal` owns reusable privacy-modal state, button hit fallback bounds, duplicate tap blocking, and open/close action routing. The consuming game still owns the actual `.gui` nodes, localized privacy text, visual styling, sound effects, and Play Console wording.

```lua
local privacy_modal = require("defold_helper.privacy_modal")

local modal = privacy_modal.create({
  lines = {
    "No personal data is collected.",
    "Local progress stays on this device.",
  },
  button_bounds = {
    min_x = 470,
    max_x = 625,
    min_y = 970,
    max_y = 1045,
  },
})

local result = privacy_modal.tap_action(modal, {
  frame = self.input_frame,
  last_handled_frame = self.last_touch_press_frame,
  x = x,
  y = y,
  button_hit = gui.pick_node(self.privacy_button, x, y),
})

if result.kind == privacy_modal.ACTIONS.OPEN then
  gui.set_enabled(self.privacy_modal_node, true)
elseif result.kind == privacy_modal.ACTIONS.CLOSE then
  gui.set_enabled(self.privacy_modal_node, false)
end
```

Keep project-specific legal copy in the consuming project, or feed it from `defold_helper.localization` through a local adapter. The helper should not include app names, policy claims, store URLs, or publisher contact data.

## Scroll State Adapter

`defold_helper.scroll` owns bounded scroll state, drag deltas, wheel steps, clamp behavior, and normalized scroll ratios. The consuming game still owns hit rectangles, GUI nodes, scrollbar colors, layout dimensions, and platform-specific input bindings.

```lua
local scroll = require("defold_helper.scroll")

local stats_scroll = scroll.create({
  min = 0,
  max = 500,
  wheel_step = 80,
})

function on_pointer_pressed(y)
  scroll.begin_drag(stats_scroll, y)
end

function on_pointer_moved(y)
  local changed = scroll.drag_to(stats_scroll, y)
  if changed then
    redraw_stats(stats_scroll.offset)
  end
end

function on_pointer_released()
  scroll.end_drag(stats_scroll)
end

function on_mouse_wheel(direction)
  local changed = scroll.apply_wheel(stats_scroll, direction)
  if changed then
    redraw_stats(stats_scroll.offset)
  end
end
```

Map mouse-wheel or platform scroll events to `"up"` and `"down"` in the consuming project. The helper intentionally does not know about Defold GUI node ids, CSS-style scrollbars, touch areas, or visual style.

## Local Leaderboard Adapter

`defold_helper.local_leaderboard` owns small local leaderboard operations: row normalization, score/time sorting, run insertion, best-score promotion, limited row copying, and compact `MM:SS` display formatting.

Keep game-specific labels and character names in a project adapter:

```lua
local leaderboard = require("defold_helper.local_leaderboard")

local M = {}

function M.record_run(rows, run)
  return leaderboard.record_run(rows, run, {
    limit = 10,
    default_character_id = "classic",
  })
end

function M.format_rows(rows)
  return leaderboard.format_rows(rows, {
    limit = 5,
    empty_text = "No runs yet",
    character_name = function(character_id)
      return character_id
    end,
  })
end

return M
```

The helper does not persist leaderboard rows or own player identity. Save files, character display names, remote leaderboard sync, and GUI node binding stay in the consuming project.

The helper modules should not depend on a specific game name, score unit, GUI file, leaderboard backend, character catalog, or advertising provider.
