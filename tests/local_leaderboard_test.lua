local assert = require("tests.assert")

local function run()
  package.loaded["defold_helper.local_leaderboard"] = nil
  local leaderboard = require("defold_helper.local_leaderboard")

  local normalized = leaderboard.normalize({
    { score = "10", time = 12, character_id = "classic" },
    { score = 20, time = 8, character_id = "heavy" },
    { score = 20, time = 14, character_id = "speedy" },
    { score = "bad", time = 99, character_id = "bad" },
  }, {
    limit = 2,
    default_character_id = "classic",
  })

  assert.equal(#normalized, 2, "normalize should cap rows by limit")
  assert.equal(normalized[1].score, 20, "normalize should sort highest score first")
  assert.equal(normalized[1].time, 14, "normalize should sort score ties by longer time")
  assert.equal(normalized[1].character_id, "speedy", "normalize should preserve character id")
  assert.equal(normalized[2].score, 20, "normalize should keep the second best limited row")

  local recorded = leaderboard.record_run({
    { score = 5, time = 10, character_id = "classic" },
  }, {
    score = 6.6,
    time = 11.2,
    character_id = "runner",
    best_score = 5,
  }, {
    limit = 5,
  })

  assert.equal(recorded.recorded, true, "record_run should record positive runs")
  assert.equal(recorded.best_score, 7, "record_run should round and promote best score")
  assert.equal(recorded.rows[1].score, 7, "record_run should insert rounded score")
  assert.equal(recorded.rows[1].character_id, "runner", "record_run should preserve run character")
  assert.equal(recorded.rows[2].score, 5, "record_run should keep previous rows")

  local ignored = leaderboard.record_run({}, {
    score = 0,
    time = 0,
    best_score = 9,
  }, {
    limit = 5,
  })

  assert.equal(ignored.recorded, false, "record_run should ignore empty runs")
  assert.equal(ignored.best_score, 9, "record_run should preserve best score for empty runs")
  assert.equal(#ignored.rows, 0, "record_run should keep empty leaderboard empty")

  local copied = leaderboard.copy_rows(recorded.rows, 1)
  assert.equal(#copied, 1, "copy_rows should honor caller limit")
  assert.equal(copied[1].score, 7, "copy_rows should copy the requested rows")

  local display = leaderboard.format_rows(recorded.rows, {
    limit = 3,
    character_name = function(character_id)
      return ({
        runner = "Runner",
        classic = "Classic",
      })[character_id]
    end,
  })

  assert.equal(display[1], "1. 7  Runner  00:11", "format_rows should render rank, score, name, and time")
  assert.equal(display[2], "2. 5  Classic  00:10", "format_rows should render previous rows")
  assert.equal(display[3], "", "format_rows should blank unused rows after the first")
  assert.equal(leaderboard.format_time(65.8), "01:05", "format_time should floor seconds into MM:SS")

  local empty_display = leaderboard.format_rows({}, {
    limit = 2,
    empty_text = "No runs yet",
  })
  assert.equal(empty_display[1], "No runs yet", "format_rows should use empty text for the first row")
  assert.equal(empty_display[2], "", "format_rows should blank remaining empty rows")
end

return run
