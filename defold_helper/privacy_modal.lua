local M = {}

M.ACTIONS = {
  NONE = "none",
  OPEN = "open",
  CLOSE = "close",
  BLOCK = "block",
}

local function option(options, key, fallback)
  options = options or {}
  if options[key] ~= nil then
    return options[key]
  end
  return fallback
end

local function copy_array(values)
  local result = {}
  for index = 1, #(values or {}) do
    result[index] = tostring(values[index] or "")
  end
  return result
end

local function copy_bounds(bounds)
  bounds = bounds or {}
  return {
    min_x = tonumber(bounds.min_x),
    max_x = tonumber(bounds.max_x),
    min_y = tonumber(bounds.min_y),
    max_y = tonumber(bounds.max_y),
  }
end

local function action(kind, handled)
  return {
    kind = kind,
    handled = handled == true,
  }
end

function M.create(options)
  options = options or {}
  return {
    open = options.open == true,
    open_frame = nil,
    duplicate_close_frames = math.max(0, math.floor(tonumber(option(options, "duplicate_close_frames", 1)) or 1)),
    button_bounds = copy_bounds(options.button_bounds),
    lines = copy_array(options.lines),
  }
end

function M.is_open(modal)
  return modal and modal.open == true
end

function M.show(modal, frame)
  modal.open = true
  modal.open_frame = frame
  return modal
end

function M.hide(modal)
  modal.open = false
  modal.open_frame = nil
  return modal
end

function M.lines(modal)
  return copy_array(modal and modal.lines or {})
end

function M.line(modal, index)
  if not modal or not index then
    return ""
  end
  return modal.lines[index] or ""
end

function M.set_lines(modal, lines)
  modal.lines = copy_array(lines)
  return modal
end

function M.point_in_button(modal, x, y, button_hit)
  if button_hit == true then
    return true
  end

  local bounds = modal and modal.button_bounds or {}
  local min_x = bounds.min_x
  local max_x = bounds.max_x
  local min_y = bounds.min_y
  local max_y = bounds.max_y
  if not min_x or not max_x or not min_y or not max_y then
    return false
  end

  local px = tonumber(x)
  local py = tonumber(y)
  if not px or not py then
    return false
  end
  return px >= min_x and px <= max_x and py >= min_y and py <= max_y
end

function M.tap_action(modal, context)
  context = context or {}
  local frame = context.frame
  local last_handled_frame = context.last_handled_frame
  local button_hit = M.point_in_button(modal, context.x, context.y, context.button_hit)

  if frame ~= nil and last_handled_frame ~= nil and last_handled_frame == frame then
    if not M.is_open(modal) and button_hit then
      M.show(modal, frame)
      return action(M.ACTIONS.OPEN, true)
    end
    return action(M.ACTIONS.BLOCK, true)
  end

  if M.is_open(modal) then
    if modal.open_frame ~= nil and frame ~= nil and frame - modal.open_frame <= modal.duplicate_close_frames then
      return action(M.ACTIONS.BLOCK, true)
    end
    M.hide(modal)
    return action(M.ACTIONS.CLOSE, true)
  end

  if button_hit then
    M.show(modal, frame)
    return action(M.ACTIONS.OPEN, true)
  end

  return action(M.ACTIONS.NONE, false)
end

return M
