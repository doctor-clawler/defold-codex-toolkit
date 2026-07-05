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

Use `localization.default_languages()` when a project needs the shared default table shape. The default locale order is:

```text
ko-KR, en, ja-JP, zh-CN, zh-TW, de-DE, fr-FR, es-419, es-ES, pt-BR, it-IT, ru-RU, tr-TR, pl-PL, th, id, vi, ar, hi-IN, nl-NL
```

Short legacy codes such as `ko`, `ja`, `zh`, `de`, `fr`, `es`, `pt`, `it`, `ru`, `tr`, `pl`, `hi`, and `nl` normalize to the matching default locale only when that canonical locale column exists in the bundle. This keeps older `en,ko` tables working while allowing new tables to use canonical locale columns.

```csv
key,ko-KR,en,ja-JP,zh-CN,zh-TW,de-DE,fr-FR,es-419,es-ES,pt-BR,it-IT,ru-RU,tr-TR,pl-PL,th,id,vi,ar,hi-IN,nl-NL,comment
ui.title,미니 서바이버,Mini Survivor,Mini Survivor,Mini Survivor,Mini Survivor,Mini Survivor,Mini Survivor,Mini Survivor,Mini Survivor,Mini Survivor,Mini Survivor,Mini Survivor,Mini Survivor,Mini Survivor,Mini Survivor,Mini Survivor,Mini Survivor,Mini Survivor,Mini Survivor,Mini Survivor,shown on title screen
ui.greeting,"안녕, {name}","Hello, {name}","Hello, {name}","Hello, {name}","Hello, {name}","Hello, {name}","Hello, {name}","Hello, {name}","Hello, {name}","Hello, {name}","Hello, {name}","Hello, {name}","Hello, {name}","Hello, {name}","Hello, {name}","Hello, {name}","Hello, {name}","Hello, {name}","Hello, {name}","Hello, {name}",supports placeholders
```

In a Defold game, list the CSV file as a custom resource and load it through a small project-local adapter:

```lua
local localization = require("defold_helper.localization")

local bundle = localization.from_resource("/assets/localization.csv", {
  sys = sys,
  default_language = "ko-KR",
  fallback_language = "en",
  languages = localization.default_languages(),
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

`defold_helper.scroll` owns bounded scroll state, drag deltas, wheel steps, clamp behavior, optional rubber-band overscroll, release velocity, inertial/spring updates, repeated-row layout math, and normalized scroll ratios. The consuming game still owns hit rectangles, GUI nodes, scrollbar colors, concrete row art, and platform-specific input bindings.

```lua
local scroll = require("defold_helper.scroll")

local stats_scroll = scroll.create({
  min = 0,
  max = 500,
  wheel_step = 80,
  overscroll_limit = 80,
  overscroll_resistance = 0.35,
  spring_stiffness = 150,
  spring_damping = 15,
  inertia_damping = 5.5,
  max_velocity = 1450,
})

function on_pointer_pressed(y, frame)
  scroll.begin_drag(stats_scroll, y, { frame = frame })
end

function on_pointer_moved(y, frame)
  local changed = scroll.drag_to(stats_scroll, y, { frame = frame })
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

function update(dt)
  local changed = scroll.update(stats_scroll, dt)
  if changed then
    redraw_stats(stats_scroll.offset)
  end
end
```

Use `scroll.layout` when a fixed pool of GUI row nodes should represent a longer list without a visible row pop:

```lua
local layout = scroll.layout({
  offset = stats_scroll.offset,
  item_count = #items,
  slot_count = #row_nodes,
  row_spacing = 132,
  top = 291,
  min_y = -342,
  max_y = 342,
  slot_half_height = 63,
})

stats_scroll.max = layout.max_offset
for _, row in ipairs(layout.slots) do
  local item = row.visible and row.item_index and items[row.item_index]
  position_row(row.slot_index, row.y, item)
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
