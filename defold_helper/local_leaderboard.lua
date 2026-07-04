local M = {}

local DEFAULT_LIMIT = 10
local DEFAULT_CHARACTER_ID = "default"

local function limit_from(options)
  return math.max(1, math.floor(tonumber((options or {}).limit) or DEFAULT_LIMIT))
end

local function default_character_id(options)
  return (options or {}).default_character_id or DEFAULT_CHARACTER_ID
end

local function rounded_score(value)
  return math.floor((tonumber(value) or 0) + 0.5)
end

function M.normalize(value, options)
  local rows = {}
  options = options or {}

  if type(value) ~= "table" then
    return rows
  end

  for _, row in ipairs(value) do
    if type(row) == "table" and tonumber(row.score) then
      rows[#rows + 1] = {
        score = tonumber(row.score) or 0,
        time = tonumber(row.time) or 0,
        character_id = row.character_id or default_character_id(options),
      }
    end
  end

  table.sort(rows, function(a, b)
    if a.score == b.score then
      return a.time > b.time
    end
    return a.score > b.score
  end)

  while #rows > limit_from(options) do
    table.remove(rows)
  end

  return rows
end

function M.record_run(existing_rows, run, options)
  options = options or {}
  run = run or {}
  local rows = M.normalize(existing_rows, options)
  local score = rounded_score(run.score)
  local time = tonumber(run.time) or 0
  local best_score = tonumber(run.best_score) or 0
  local recorded = score > 0 or time > 0

  if recorded then
    rows[#rows + 1] = {
      score = score,
      time = time,
      character_id = run.character_id or default_character_id(options),
    }
    rows = M.normalize(rows, options)
    if score > best_score then
      best_score = score
    end
  elseif #rows > 0 and rows[1].score > best_score then
    best_score = rows[1].score
  end

  return {
    rows = rows,
    best_score = best_score,
    recorded = recorded,
  }
end

function M.copy_rows(rows, limit)
  local copied = {}
  local max_rows = math.max(0, math.floor(tonumber(limit) or #rows or 0))
  rows = rows or {}
  for index = 1, math.min(max_rows, #rows) do
    copied[index] = rows[index]
  end
  return copied
end

function M.format_time(seconds)
  local mins = math.floor((tonumber(seconds) or 0) / 60)
  local secs = math.floor((tonumber(seconds) or 0) % 60)
  return string.format("%02d:%02d", mins, secs)
end

function M.format_rows(rows, options)
  options = options or {}
  local limit = limit_from(options)
  local output = {}
  local character_name = options.character_name
  rows = rows or {}

  for index = 1, limit do
    local row = rows[index]
    if row then
      local name = row.character_id or default_character_id(options)
      if type(character_name) == "function" then
        name = character_name(row.character_id) or name
      end
      output[index] = string.format(
        "%d. %d  %s  %s",
        index,
        math.floor(tonumber(row.score) or 0),
        name,
        M.format_time(row.time)
      )
    elseif index == 1 then
      output[index] = options.empty_text or "No runs yet"
    else
      output[index] = ""
    end
  end

  return output
end

return M
