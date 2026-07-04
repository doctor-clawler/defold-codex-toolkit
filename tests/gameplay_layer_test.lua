local assert = require("tests.assert")

local function run()
  package.loaded["defold_helper.gameplay_layer"] = nil
  local gameplay = require("defold_helper.gameplay_layer")

  assert.equal(gameplay.STATES.PLAYING, "playing", "gameplay layer should expose the reusable playing state")
  assert.equal(gameplay.STATES.GAME_OVER, "game_over", "gameplay layer should expose the reusable game-over state")
  assert.equal(gameplay.STATES.OUT_OF_PLAYS, "out_of_plays", "gameplay layer should expose the reusable out-of-plays state")

  assert.equal(gameplay.can_drop({
    is_transitioning = false,
    game_state = "playing",
    current_block_id = 42,
  }), true, "playing sessions with a current block should accept drop input")
  assert.equal(gameplay.can_drop({
    is_transitioning = true,
    game_state = "playing",
    current_block_id = 42,
  }), false, "transitioning sessions should reject drop input")
  assert.equal(gameplay.can_drop({
    is_transitioning = false,
    game_state = "game_over",
    current_block_id = 42,
  }), false, "game-over sessions should reject drop input")

  local records = {
    current_score = 3,
    last_score = 7,
    best_score = 11,
    total_score = 40,
    current_combo = 4,
    best_combo = 5,
  }

  assert.equal(gameplay.total_score(records, "playing"), 43, "playing HUD totals should include the active run")
  assert.equal(gameplay.total_score(records, "game_over"), 40, "finished HUD totals should use the persisted total")
  assert.equal(gameplay.best_combo(records), 5, "best combo should preserve the all-time best")
  assert.equal(gameplay.best_combo({ current_combo = 8, best_combo = 5 }), 8, "best combo should include the active run max")

  local hud = gameplay.hud_payload({
    score = 123,
    perfect_combo = 4,
    game_state = "playing",
    records = records,
  }, {
    combo_target = 10,
    pulse_combo = true,
  })
  assert.equal(hud.score, 123, "HUD payload should expose the score")
  assert.equal(hud.perfect_combo, 4, "HUD payload should expose the active combo")
  assert.equal(hud.combo_target, 10, "HUD payload should expose the combo target")
  assert.equal(hud.pulse_combo, true, "HUD payload should carry pulse intent")
  assert.equal(hud.current_score, 3, "HUD payload should expose current score")
  assert.equal(hud.total_score, 43, "HUD payload should compute visible total score")
  assert.equal(hud.best_combo, 5, "HUD payload should expose best combo")

  local result = gameplay.result_payload({
    score = 123,
    records = records,
    play_credit_payload = {
      remaining_plays = 0,
      daily_free_plays = 10,
      rewarded_ad_ready = true,
    },
    extra = {
      play_credit_blocked = true,
    },
  })
  assert.equal(result.score, 123, "result payload should include score")
  assert.equal(result.current_score, 3, "result payload should include current score")
  assert.equal(result.last_score, 7, "result payload should include last score")
  assert.equal(result.total_score, 40, "result payload should include persisted total score")
  assert.equal(result.current_combo, 4, "result payload should include current combo")
  assert.equal(result.remaining_plays, 0, "result payload should merge play credit state")
  assert.equal(result.play_credit_blocked, true, "result payload should merge caller extras")

  local reset = gameplay.round_reset_fields(records)
  assert.equal(reset.game_state, "playing", "round reset should enter playing")
  assert.equal(reset.score, 0, "round reset should clear score")
  assert.equal(reset.perfect_combo, 0, "round reset should clear combo")
  assert.equal(reset.success_count, 0, "round reset should clear success count")
  assert.equal(reset.records.current_score, 0, "round reset should clear current score")
  assert.equal(reset.records.last_score, 7, "round reset should preserve last score")
  assert.equal(reset.records.best_score, 11, "round reset should preserve best score")
  assert.equal(reset.records.total_score, 40, "round reset should preserve total score")
  assert.equal(reset.records.best_combo, 5, "round reset should preserve best combo")
end

return run
