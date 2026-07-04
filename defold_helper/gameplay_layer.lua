local M = {}

M.STATES = {
  PLAYING = "playing",
  GAME_OVER = "game_over",
  OUT_OF_PLAYS = "out_of_plays",
}

local function count(value)
  local number = math.floor(tonumber(value) or 0)
  if number < 0 then
    return 0
  end
  return number
end

local function records_from(source)
  source = source or {}
  return source.records or source
end

local function merge_into(target, source)
  for key, value in pairs(source or {}) do
    target[key] = value
  end
  return target
end

function M.can_drop(session)
  session = session or {}
  if session.is_transitioning then
    return false
  end
  if session.game_state == M.STATES.GAME_OVER or session.game_state == M.STATES.OUT_OF_PLAYS then
    return false
  end
  return session.current_block_id ~= nil
end

function M.total_score(records, game_state)
  records = records or {}
  local total = count(records.total_score)
  if game_state == M.STATES.PLAYING then
    return total + count(records.current_score)
  end
  return total
end

function M.best_combo(records)
  records = records or {}
  return math.max(count(records.best_combo), count(records.current_combo))
end

function M.hud_payload(session, options)
  session = session or {}
  options = options or {}
  local records = records_from(session)
  return merge_into({
    score = count(session.score),
    perfect_combo = count(session.perfect_combo),
    combo_target = options.combo_target,
    pulse_combo = options.pulse_combo == true,
    current_score = count(records.current_score),
    last_score = count(records.last_score),
    best_score = count(records.best_score),
    total_score = M.total_score(records, session.game_state),
    current_combo = count(records.current_combo),
    best_combo = M.best_combo(records),
  }, options.extra)
end

function M.result_payload(options)
  options = options or {}
  local records = records_from(options)
  local payload = merge_into({}, options.play_credit_payload)

  payload.score = count(options.score)
  payload.current_score = count(records.current_score)
  payload.last_score = count(records.last_score)
  payload.best_score = count(records.best_score)
  payload.total_score = count(records.total_score)
  payload.current_combo = count(records.current_combo)
  payload.best_combo = M.best_combo(records)

  return merge_into(payload, options.extra)
end

function M.round_reset_fields(records)
  records = records_from(records)
  return {
    game_state = M.STATES.PLAYING,
    success_count = 0,
    score = 0,
    perfect_combo = 0,
    records = {
      current_score = 0,
      last_score = count(records.last_score),
      best_score = count(records.best_score),
      total_score = count(records.total_score),
      current_combo = 0,
      best_combo = count(records.best_combo),
    },
  }
end

return M
