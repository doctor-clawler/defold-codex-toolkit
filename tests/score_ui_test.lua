local assert = require("tests.assert")

local function run()
  package.loaded["defold_helper.score_ui"] = nil
  local score_ui = require("defold_helper.score_ui")

  local hud = score_ui.hud_labels({
    total_score = 33,
    current_score = 12,
    current_combo = 3,
  }, {
    total_label = "TOTAL",
    current_label = "RUN",
    combo_label = "COMBO",
    unit = "m",
  })
  assert.equal(hud.total, "TOTAL 33m", "HUD total label should be reusable")
  assert.equal(hud.current, "RUN 12m", "HUD current label should be reusable")
  assert.equal(hud.combo, "COMBO x3", "HUD combo label should be reusable")

  local result = score_ui.result_text({
    total_score = 51,
    current_score = 18,
    best_score = 30,
    current_combo = 3,
    best_combo = 5,
  }, {
    total_label = "TOTAL",
    current_label = "RUN",
    combo_label = "COMBO",
    unit = "m",
  })
  assert.equal(result, "TOTAL 51m\nRUN 18m / 30m\nCOMBO x3 / x5", "result text should format total, current/best, and combo")

  assert.equal(score_ui.is_new_best({ current_score = 31, best_score = 30 }), true, "new best should compare current score against best")
  assert.equal(score_ui.is_new_best({ current_score = 30, best_score = 30 }), false, "tying best should not count as a new best")
end

return run
