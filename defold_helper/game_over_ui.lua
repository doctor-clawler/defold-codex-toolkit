local score_ui = require("defold_helper.score_ui")

local M = {}

M.ACTIONS = {
  NONE = "none",
  CLOSE_LEADERBOARD = "close_leaderboard",
  SELECT_LEADERBOARD_METRIC = "select_leaderboard_metric",
  SAVE_PLAYER_ID = "save_player_id",
  SKIP_PLAYER_ID = "skip_player_id",
  FOCUS_PLAYER_ID = "focus_player_id",
  OPEN_PLAYER_ID_PROMPT = "open_player_id_prompt",
  OPEN_LEADERBOARD = "open_leaderboard",
  WATCH_REWARDED_AD = "watch_rewarded_ad",
  RESTART = "restart",
}

function M.score_count(value, fallback)
  return score_ui.score_count(value, fallback)
end

function M.result_score_text(values, options)
  return score_ui.result_text(values, options)
end

local function option(options, key, fallback)
  options = options or {}
  if options[key] ~= nil then
    return options[key]
  end
  return fallback
end

function M.play_credit_labels(state, options)
  state = state or {}
  options = options or {}
  local remaining = M.score_count(state.remaining_plays, option(options, "remaining_plays", 10))
  local daily_free_plays = M.score_count(state.daily_free_plays, option(options, "daily_free_plays", 10))
  local reward_grant = M.score_count(state.reward_grant, option(options, "reward_grant", 10))
  local restart_label = option(options, "restart_label", "Continue")
  local rewarded_ad_label = option(options, "rewarded_ad_label", "Watch Ad")
  return {
    restart = string.format("%s\n%d/%d", restart_label, remaining, daily_free_plays),
    rewarded_ad = string.format("%s\n+%d", rewarded_ad_label, reward_grant),
  }
end

function M.control_states(state)
  state = state or {}
  local visible = state.visible == true
  local has_plays = M.score_count(state.remaining_plays, 10) > 0
  return {
    title = visible,
    player_name = visible,
    final_score = visible,
    leaderboard = visible,
    restart = visible and has_plays,
    rewarded_ad = visible and not has_plays,
  }
end

local function action(kind, extra)
  local result = { kind = kind }
  for key, value in pairs(extra or {}) do
    result[key] = value
  end
  return result
end

function M.tap_action(context)
  context = context or {}
  local hits = context.hits or {}

  if not context.game_over_visible then
    return action(M.ACTIONS.NONE)
  end

  if context.leaderboard_popup_visible then
    if hits.leaderboard_close then
      return action(M.ACTIONS.CLOSE_LEADERBOARD)
    end
    if hits.leaderboard_metric then
      return action(M.ACTIONS.SELECT_LEADERBOARD_METRIC, {
        metric = hits.leaderboard_metric,
      })
    end
    return action(M.ACTIONS.NONE)
  end

  if context.player_id_prompt_visible then
    if hits.player_id_save then
      return action(M.ACTIONS.SAVE_PLAYER_ID)
    end
    if hits.player_id_skip then
      return action(M.ACTIONS.SKIP_PLAYER_ID)
    end
    if hits.player_id_input then
      return action(M.ACTIONS.FOCUS_PLAYER_ID)
    end
    return action(M.ACTIONS.NONE)
  end

  if hits.open_player_id then
    return action(M.ACTIONS.OPEN_PLAYER_ID_PROMPT)
  end
  if hits.open_leaderboard then
    return action(M.ACTIONS.OPEN_LEADERBOARD)
  end
  if hits.watch_rewarded_ad then
    return action(M.ACTIONS.WATCH_REWARDED_AD)
  end
  if hits.restart then
    return action(M.ACTIONS.RESTART)
  end
  return action(M.ACTIONS.NONE)
end

return M
