local M = {}

local DEFAULT_APP_NAME = "game"
local DEFAULT_FILE_NAME = "score_records"

local function count(value)
  local number = math.floor(tonumber(value) or 0)
  if number < 0 then
    return 0
  end
  return number
end

local function resolve_sys(sys_api)
  if sys_api ~= nil then
    return sys_api
  end
  return rawget(_G, "sys")
end

local function options_or_empty(options)
  if type(options) == "table" then
    return options
  end
  return {
    sys = options,
  }
end

local function save_path(options)
  local sys_api = resolve_sys(options.sys)
  if not sys_api or type(sys_api.get_save_file) ~= "function" then
    return nil, sys_api
  end

  local app_name = options.app_name or DEFAULT_APP_NAME
  local file_name = options.file_name or DEFAULT_FILE_NAME
  return sys_api.get_save_file(app_name, file_name), sys_api
end

local function field_name(options, key)
  local fields = options.fields or {}
  return fields[key] or key
end

local function default_state()
  return {
    current_score = 0,
    last_score = 0,
    best_score = 0,
    total_score = 0,
    current_combo = 0,
    best_combo = 0,
  }
end

function M.load(options)
  options = options_or_empty(options)
  local path, sys_api = save_path(options)
  local state = default_state()

  if not path or type(sys_api.load) ~= "function" then
    return state
  end

  local persisted = sys_api.load(path)
  if type(persisted) ~= "table" then
    return state
  end

  state.last_score = count(persisted[field_name(options, "last_score")])
  state.best_score = count(persisted[field_name(options, "best_score")])
  state.total_score = count(persisted[field_name(options, "total_score")])
  state.best_combo = count(persisted[field_name(options, "best_combo")])
  return state
end

function M.finish_round(state)
  state = state or {}
  local current_score = count(state.current_score)
  local current_combo = count(state.current_combo)
  return {
    current_score = current_score,
    last_score = current_score,
    best_score = math.max(count(state.best_score), current_score),
    total_score = count(state.total_score) + current_score,
    current_combo = current_combo,
    best_combo = math.max(count(state.best_combo), current_combo),
  }
end

function M.cumulative_score(state)
  state = state or {}
  return count(state.total_score) + count(state.current_score)
end

function M.reset_current_score(state)
  state = state or {}
  return {
    current_score = 0,
    last_score = count(state.last_score),
    best_score = count(state.best_score),
    total_score = count(state.total_score),
    current_combo = 0,
    best_combo = count(state.best_combo),
  }
end

function M.save(state, options)
  options = options_or_empty(options)
  local path, sys_api = save_path(options)
  if not path or type(sys_api.save) ~= "function" then
    return
  end

  local payload = {}
  payload[field_name(options, "last_score")] = count((state or {}).last_score)
  payload[field_name(options, "best_score")] = count((state or {}).best_score)
  payload[field_name(options, "total_score")] = count((state or {}).total_score)
  payload[field_name(options, "best_combo")] = count((state or {}).best_combo)
  sys_api.save(path, payload)
end

return M
