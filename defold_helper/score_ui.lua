local M = {}

local function count(value)
  local number = math.floor(tonumber(value) or 0)
  if number < 0 then
    return 0
  end
  return number
end

local function option(options, key, fallback)
  options = options or {}
  if options[key] ~= nil then
    return options[key]
  end
  return fallback
end

local function unit(options)
  return option(options, "unit", "")
end

function M.score_count(value, fallback)
  if value == nil and fallback ~= nil then
    return count(fallback)
  end
  return count(value)
end

function M.hud_labels(values, options)
  values = values or {}
  options = options or {}
  local suffix = unit(options)
  local total_label = option(options, "total_label", "TOTAL")
  local current_label = option(options, "current_label", "RUN")
  local combo_label = option(options, "combo_label", "COMBO")

  return {
    total = string.format("%s %d%s", total_label, count(values.total_score), suffix),
    current = string.format("%s %d%s", current_label, count(values.current_score), suffix),
    combo = string.format("%s x%d", combo_label, count(values.current_combo)),
  }
end

function M.result_text(values, options)
  values = values or {}
  options = options or {}
  local suffix = unit(options)
  local total_label = option(options, "total_label", "TOTAL")
  local current_label = option(options, "current_label", "RUN")
  local combo_label = option(options, "combo_label", "COMBO")

  return string.format(
    "%s %d%s\n%s %d%s / %d%s\n%s x%d / x%d",
    total_label,
    count(values.total_score),
    suffix,
    current_label,
    count(values.current_score),
    suffix,
    count(values.best_score),
    suffix,
    combo_label,
    count(values.current_combo),
    count(values.best_combo)
  )
end

function M.is_new_best(values)
  values = values or {}
  return count(values.current_score) > count(values.best_score)
end

return M
