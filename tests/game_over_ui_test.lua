local assert = require("tests.assert")

local function run()
  package.loaded["defold_helper.game_over_ui"] = nil
  local game_over_ui = require("defold_helper.game_over_ui")

  assert.equal(
    game_over_ui.result_score_text({
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
    }),
    "TOTAL 51m\nRUN 18m / 30m\nCOMBO x3 / x5",
    "result score text should format generic score records"
  )

  local labels = game_over_ui.play_credit_labels({
    remaining_plays = 2,
    daily_free_plays = 10,
    reward_grant = 4,
  })
  assert.equal(labels.restart, "Continue\n2/10", "continue label should include remaining daily plays")
  assert.equal(labels.rewarded_ad, "Watch Ad\n+4", "reward label should include granted plays")

  local with_plays = game_over_ui.control_states({
    visible = true,
    remaining_plays = 2,
  })
  assert.equal(with_plays.title, true, "visible controls should show result title")
  assert.equal(with_plays.restart, true, "visible controls should show continue when plays remain")
  assert.equal(with_plays.rewarded_ad, false, "visible controls should hide ads when plays remain")

  local without_plays = game_over_ui.control_states({
    visible = true,
    remaining_plays = 0,
  })
  assert.equal(without_plays.restart, false, "visible controls should hide continue when no plays remain")
  assert.equal(without_plays.rewarded_ad, true, "visible controls should show ads when no plays remain")

  local leaderboard_tab = game_over_ui.tap_action({
    game_over_visible = true,
    leaderboard_popup_visible = true,
    hits = {
      leaderboard_metric = "combo",
    },
  })
  assert.equal(leaderboard_tab.kind, game_over_ui.ACTIONS.SELECT_LEADERBOARD_METRIC, "metric tab hit should select a metric")
  assert.equal(leaderboard_tab.metric, "combo", "metric tab action should carry the selected metric")

  local top_level = game_over_ui.tap_action({
    game_over_visible = true,
    hits = {
      open_player_id = true,
      restart = true,
    },
  })
  assert.equal(top_level.kind, game_over_ui.ACTIONS.OPEN_PLAYER_ID_PROMPT, "player id hit should win over lower-priority result actions")
end

return run
