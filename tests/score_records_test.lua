local assert = require("tests.assert")

local function run()
  package.loaded["defold_helper.score_records"] = nil
  local score_records = require("defold_helper.score_records")

  local default_state = score_records.load(nil)
  assert.equal(default_state.current_score, 0, "load without sys should default current score")
  assert.equal(default_state.last_score, 0, "load without sys should default last score")
  assert.equal(default_state.best_score, 0, "load without sys should default best score")
  assert.equal(default_state.total_score, 0, "load without sys should default total score")
  assert.equal(default_state.current_combo, 0, "load without sys should default current combo")
  assert.equal(default_state.best_combo, 0, "load without sys should default best combo")

  local saved_payload
  local fake_sys = {
    get_save_file = function(app_name, file_name)
      assert.equal(app_name, "portable-game", "score records should allow a caller-owned app name")
      assert.equal(file_name, "score_records", "score records should allow a caller-owned file name")
      return "/tmp/portable-score-records"
    end,
    load = function()
      return {
        last_score = "9.8",
        best_score = 12.3,
        total_score = 32,
        best_combo = "4",
        current_score = 99,
        current_combo = 99,
      }
    end,
    save = function(path, payload)
      assert.equal(path, "/tmp/portable-score-records", "score records should save to the configured path")
      saved_payload = payload
    end,
  }

  local loaded = score_records.load({
    sys = fake_sys,
    app_name = "portable-game",
    file_name = "score_records",
  })
  assert.equal(loaded.current_score, 0, "load should keep current score runtime-only")
  assert.equal(loaded.last_score, 9, "load should floor persisted last score")
  assert.equal(loaded.best_score, 12, "load should floor persisted best score")
  assert.equal(loaded.total_score, 32, "load should floor persisted total score")
  assert.equal(loaded.current_combo, 0, "load should keep current combo runtime-only")
  assert.equal(loaded.best_combo, 4, "load should floor persisted best combo")

  local active_round = {
    current_score = 7,
    last_score = loaded.last_score,
    best_score = loaded.best_score,
    total_score = loaded.total_score,
    current_combo = 5,
    best_combo = loaded.best_combo,
  }
  assert.equal(score_records.cumulative_score(active_round), 39, "cumulative_score should include the active round")

  local finished = score_records.finish_round(active_round)
  assert.equal(finished.current_score, 7, "finish_round should preserve the finished current score")
  assert.equal(finished.last_score, 7, "finish_round should mirror current score to last score")
  assert.equal(finished.best_score, 12, "finish_round should keep the larger best score")
  assert.equal(finished.total_score, 39, "finish_round should add current score to total")
  assert.equal(finished.current_combo, 5, "finish_round should preserve current combo until reset")
  assert.equal(finished.best_combo, 5, "finish_round should promote current combo when it beats best")

  score_records.save(finished, {
    sys = fake_sys,
    app_name = "portable-game",
    file_name = "score_records",
  })
  assert.equal(saved_payload.last_score, 7, "save should persist last score")
  assert.equal(saved_payload.best_score, 12, "save should persist best score")
  assert.equal(saved_payload.total_score, 39, "save should persist total score")
  assert.equal(saved_payload.best_combo, 5, "save should persist best combo")
  assert.equal(saved_payload.current_score, nil, "save should not persist runtime current score")
  assert.equal(saved_payload.current_combo, nil, "save should not persist runtime current combo")
end

return run
