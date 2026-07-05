local M = {}

local DEFAULT_MIN = 0
local DEFAULT_MAX = 0
local DEFAULT_WHEEL_STEP = 80
local DEFAULT_DRAG_SCALE = 1
local DEFAULT_EPSILON = 1

local function number_or(value, fallback)
  local number = tonumber(value)
  if number == nil then
    return fallback
  end
  return number
end

function M.clamp(value, min_value, max_value)
  value = number_or(value, 0)
  min_value = number_or(min_value, DEFAULT_MIN)
  max_value = number_or(max_value, min_value)
  if max_value < min_value then
    min_value, max_value = max_value, min_value
  end
  if value < min_value then return min_value end
  if value > max_value then return max_value end
  return value
end

local function apply_options(state, options)
  options = options or {}
  if options.min ~= nil then
    state.min = number_or(options.min, DEFAULT_MIN)
  elseif state.min == nil then
    state.min = DEFAULT_MIN
  end
  if options.max ~= nil then
    state.max = number_or(options.max, state.min or DEFAULT_MAX)
  elseif state.max == nil then
    state.max = DEFAULT_MAX
  end
  if state.max < state.min then
    state.min, state.max = state.max, state.min
  end
  if options.wheel_step ~= nil then
    state.wheel_step = math.max(0, number_or(options.wheel_step, DEFAULT_WHEEL_STEP))
  elseif state.wheel_step == nil then
    state.wheel_step = DEFAULT_WHEEL_STEP
  end
  if options.drag_scale ~= nil then
    state.drag_scale = number_or(options.drag_scale, DEFAULT_DRAG_SCALE)
  elseif state.drag_scale == nil then
    state.drag_scale = DEFAULT_DRAG_SCALE
  end
  if options.epsilon ~= nil then
    state.epsilon = math.max(0, number_or(options.epsilon, DEFAULT_EPSILON))
  elseif state.epsilon == nil then
    state.epsilon = DEFAULT_EPSILON
  end
  if options.offset ~= nil or state.offset == nil then
    state.offset = number_or(options.offset, state.offset or state.min)
  end
  state.offset = M.clamp(state.offset, state.min, state.max)
  state.dragging = state.dragging == true
  return state
end

function M.create(options)
  return apply_options({}, options)
end

function M.configure(state, options)
  return apply_options(state or {}, options)
end

function M.reset(state, options)
  state = apply_options(state or {}, options)
  state.offset = M.clamp(options and options.offset or state.min, state.min, state.max)
  state.dragging = false
  state.last_position = nil
  return state
end

function M.end_drag(state)
  if not state then
    return state
  end
  state.dragging = false
  state.last_position = nil
  return state
end

function M.begin_drag(state, position, options)
  state = apply_options(state or {}, options)
  state.dragging = true
  state.last_position = number_or(position, 0)
  return state
end

function M.scroll_by(state, delta, options)
  state = apply_options(state or {}, options)
  local previous = state.offset or state.min or 0
  state.offset = M.clamp(previous + number_or(delta, 0), state.min, state.max)
  return math.abs(state.offset - previous) >= (state.epsilon or DEFAULT_EPSILON), state.offset, previous
end

function M.drag_to(state, position, options)
  state = apply_options(state or {}, options)
  if state.dragging ~= true then
    return false, state.offset, state.offset
  end
  local next_position = number_or(position, state.last_position or 0)
  local previous_position = state.last_position or next_position
  state.last_position = next_position
  return M.scroll_by(state, (next_position - previous_position) * (state.drag_scale or DEFAULT_DRAG_SCALE))
end

function M.wheel_delta(direction, options)
  options = options or {}
  local step = number_or(options.step or options.wheel_step, DEFAULT_WHEEL_STEP)
  if direction == "up" or direction == -1 then
    return -step
  end
  if direction == "down" or direction == 1 then
    return step
  end
  return number_or(direction, 0) * step
end

function M.apply_wheel(state, direction, options)
  state = apply_options(state or {}, options)
  return M.scroll_by(state, M.wheel_delta(direction, state))
end

function M.ratio(state_or_offset, min_value, max_value)
  local offset = state_or_offset
  if type(state_or_offset) == "table" then
    offset = state_or_offset.offset
    min_value = state_or_offset.min
    max_value = state_or_offset.max
  end
  min_value = number_or(min_value, DEFAULT_MIN)
  max_value = number_or(max_value, min_value)
  if max_value <= min_value then
    return 0
  end
  return (M.clamp(offset, min_value, max_value) - min_value) / (max_value - min_value)
end

return M
