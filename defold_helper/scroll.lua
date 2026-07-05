local M = {}

local DEFAULT_MIN = 0
local DEFAULT_MAX = 0
local DEFAULT_WHEEL_STEP = 80
local DEFAULT_DRAG_SCALE = 1
local DEFAULT_EPSILON = 1
local DEFAULT_OVERSCROLL_LIMIT = 0
local DEFAULT_OVERSCROLL_RESISTANCE = 0.35
local DEFAULT_SPRING_STIFFNESS = 150
local DEFAULT_SPRING_DAMPING = 15
local DEFAULT_INERTIA_DAMPING = 5.5
local DEFAULT_MAX_VELOCITY = 1000000000
local DEFAULT_LAYOUT_TOP = 0
local DEFAULT_SLOT_COUNT = 0
local DEFAULT_ROW_SPACING = 1
local DEFAULT_SLOT_HALF_HEIGHT = 0

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

function M.clamp_overscroll(value, min_value, max_value, overscroll_limit)
  overscroll_limit = math.max(0, number_or(overscroll_limit, DEFAULT_OVERSCROLL_LIMIT))
  return M.clamp(value, number_or(min_value, DEFAULT_MIN) - overscroll_limit, number_or(max_value, DEFAULT_MAX) + overscroll_limit)
end

local function clamp_velocity(state, velocity)
  local max_velocity = math.max(0, number_or(state.max_velocity, DEFAULT_MAX_VELOCITY))
  return M.clamp(number_or(velocity, 0), -max_velocity, max_velocity)
end

local function rubber_band_offset(state, raw_offset)
  local min_value = state.min or DEFAULT_MIN
  local max_value = state.max or DEFAULT_MAX
  local overscroll_limit = state.overscroll_limit or DEFAULT_OVERSCROLL_LIMIT
  if overscroll_limit <= 0 then
    return M.clamp(raw_offset, min_value, max_value)
  end

  local resistance = math.max(0, number_or(state.overscroll_resistance, DEFAULT_OVERSCROLL_RESISTANCE))
  if raw_offset < min_value then
    return min_value - math.min(overscroll_limit, (min_value - raw_offset) * resistance)
  end
  if raw_offset > max_value then
    return max_value + math.min(overscroll_limit, (raw_offset - max_value) * resistance)
  end
  return raw_offset
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
  if options.overscroll_limit ~= nil then
    state.overscroll_limit = math.max(0, number_or(options.overscroll_limit, DEFAULT_OVERSCROLL_LIMIT))
  elseif state.overscroll_limit == nil then
    state.overscroll_limit = DEFAULT_OVERSCROLL_LIMIT
  end
  if options.overscroll_resistance ~= nil then
    state.overscroll_resistance = math.max(0, number_or(options.overscroll_resistance, DEFAULT_OVERSCROLL_RESISTANCE))
  elseif state.overscroll_resistance == nil then
    state.overscroll_resistance = DEFAULT_OVERSCROLL_RESISTANCE
  end
  if options.spring_stiffness ~= nil then
    state.spring_stiffness = math.max(0, number_or(options.spring_stiffness, DEFAULT_SPRING_STIFFNESS))
  elseif state.spring_stiffness == nil then
    state.spring_stiffness = DEFAULT_SPRING_STIFFNESS
  end
  if options.spring_damping ~= nil then
    state.spring_damping = math.max(0, number_or(options.spring_damping, DEFAULT_SPRING_DAMPING))
  elseif state.spring_damping == nil then
    state.spring_damping = DEFAULT_SPRING_DAMPING
  end
  if options.inertia_damping ~= nil then
    state.inertia_damping = math.max(0, number_or(options.inertia_damping, DEFAULT_INERTIA_DAMPING))
  elseif state.inertia_damping == nil then
    state.inertia_damping = DEFAULT_INERTIA_DAMPING
  end
  if options.max_velocity ~= nil then
    state.max_velocity = math.max(0, number_or(options.max_velocity, DEFAULT_MAX_VELOCITY))
  elseif state.max_velocity == nil then
    state.max_velocity = DEFAULT_MAX_VELOCITY
  end
  if options.velocity ~= nil or state.velocity == nil then
    state.velocity = clamp_velocity(state, number_or(options.velocity, state.velocity or 0))
  end
  if options.offset ~= nil or state.offset == nil then
    state.offset = number_or(options.offset, state.offset or state.min)
  end
  state.offset = M.clamp_overscroll(state.offset, state.min, state.max, state.overscroll_limit)
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
  state.velocity = 0
  state.dragging = false
  state.raw_offset = nil
  state.last_position = nil
  state.last_frame = nil
  state.spring_target = nil
  return state
end

function M.end_drag(state)
  if not state then
    return state
  end
  state.dragging = false
  state.raw_offset = state.offset
  local target = M.clamp(state.offset, state.min, state.max)
  state.spring_target = target ~= state.offset and target or nil
  state.last_position = nil
  state.last_frame = nil
  return state
end

function M.begin_drag(state, position, options)
  state = apply_options(state or {}, options)
  state.dragging = true
  state.velocity = 0
  state.raw_offset = state.offset or state.min or 0
  state.spring_target = nil
  state.last_position = number_or(position, 0)
  state.last_frame = options and options.frame or nil
  return state
end

function M.scroll_by(state, delta, options)
  state = apply_options(state or {}, options)
  local previous = state.offset or state.min or 0
  state.offset = M.clamp(previous + number_or(delta, 0), state.min, state.max)
  state.raw_offset = state.offset
  return math.abs(state.offset - previous) >= (state.epsilon or DEFAULT_EPSILON), state.offset, previous
end

function M.drag_to(state, position, options)
  state = apply_options(state or {}, options)
  if state.dragging ~= true then
    return false, state.offset, state.offset
  end
  local next_position = number_or(position, state.last_position or 0)
  local previous_position = state.last_position or next_position
  local previous_offset = state.offset or state.min or 0
  state.last_position = next_position
  state.raw_offset = (state.raw_offset or previous_offset) + ((next_position - previous_position) * (state.drag_scale or DEFAULT_DRAG_SCALE))
  state.offset = rubber_band_offset(state, state.raw_offset)

  local elapsed_frames = nil
  if options and options.frame ~= nil and state.last_frame ~= nil then
    elapsed_frames = math.max(1, number_or(options.frame, state.last_frame) - state.last_frame)
    state.last_frame = options.frame
  elseif options and options.frame ~= nil then
    state.last_frame = options.frame
  end
  if options and options.dt ~= nil and number_or(options.dt, 0) > 0 then
    state.velocity = clamp_velocity(state, (state.offset - previous_offset) / number_or(options.dt, 1 / 60))
  elseif elapsed_frames then
    state.velocity = clamp_velocity(state, (state.offset - previous_offset) * 60 / elapsed_frames)
  end

  return math.abs(state.offset - previous_offset) >= (state.epsilon or DEFAULT_EPSILON), state.offset, previous_offset
end

function M.update(state, dt, options)
  state = apply_options(state or {}, options)
  if state.dragging then
    return false, state.offset, state.offset
  end

  dt = math.max(0, number_or(dt, 0))
  local previous = state.offset or state.min or 0
  local clamped = M.clamp(previous, state.min, state.max)
  if state.spring_target == nil and clamped ~= previous then
    state.spring_target = clamped
  end
  local target = state.spring_target or clamped
  local velocity = clamp_velocity(state, state.velocity or 0)
  local displacement = previous - target
  local epsilon = state.epsilon or DEFAULT_EPSILON

  if math.abs(displacement) <= epsilon and math.abs(velocity) <= epsilon then
    state.offset = target
    state.raw_offset = target
    state.velocity = 0
    state.spring_target = nil
    return previous ~= target or velocity ~= 0, state.offset, previous
  end

  if math.abs(displacement) > epsilon then
    velocity = velocity - displacement * (state.spring_stiffness or DEFAULT_SPRING_STIFFNESS) * dt
    velocity = velocity * math.max(0, 1 - (state.spring_damping or DEFAULT_SPRING_DAMPING) * dt)
  else
    velocity = velocity * math.max(0, 1 - (state.inertia_damping or DEFAULT_INERTIA_DAMPING) * dt)
  end

  state.offset = M.clamp_overscroll(previous + velocity * dt, state.min, state.max, state.overscroll_limit)
  state.raw_offset = state.offset
  state.velocity = clamp_velocity(state, velocity)
  return math.abs(state.offset - previous) >= epsilon or math.abs(state.velocity) >= epsilon, state.offset, previous
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

function M.max_offset(options_or_item_count, slot_count, row_spacing)
  local item_count = options_or_item_count
  if type(options_or_item_count) == "table" then
    item_count = options_or_item_count.item_count or options_or_item_count.count or 0
    slot_count = options_or_item_count.slot_count or slot_count
    row_spacing = options_or_item_count.row_spacing or row_spacing
  end
  item_count = math.max(0, math.floor(number_or(item_count, 0)))
  slot_count = math.max(0, math.floor(number_or(slot_count, DEFAULT_SLOT_COUNT)))
  row_spacing = math.max(0, number_or(row_spacing, DEFAULT_ROW_SPACING))
  return math.max(0, item_count - slot_count) * row_spacing
end

function M.layout(options)
  options = options or {}
  local item_count = math.max(0, math.floor(number_or(options.item_count or options.count, 0)))
  local slot_count = math.max(0, math.floor(number_or(options.slot_count, DEFAULT_SLOT_COUNT)))
  local row_spacing = math.max(1, number_or(options.row_spacing, DEFAULT_ROW_SPACING))
  local offset = number_or(options.offset, 0)
  local top = number_or(options.top or options.top_y, DEFAULT_LAYOUT_TOP)
  local min_y = number_or(options.min_y, -1000000000)
  local max_y = number_or(options.max_y, 1000000000)
  local slot_half_height = math.max(0, number_or(options.slot_half_height, DEFAULT_SLOT_HALF_HEIGHT))
  local max_offset = M.max_offset(item_count, slot_count, row_spacing)
  local bounded_offset = M.clamp(offset, 0, max_offset)
  local first_index = math.floor(bounded_offset / row_spacing) + 1
  local row_offset = offset - ((first_index - 1) * row_spacing)
  local slots = {}

  for slot_index = 1, slot_count do
    local item_index = first_index + slot_index - 1
    local y = top - ((slot_index - 1) * row_spacing) + row_offset
    local has_item = item_index <= item_count
    slots[slot_index] = {
      slot_index = slot_index,
      item_index = has_item and item_index or nil,
      y = y,
      visible = has_item and y >= min_y - slot_half_height and y <= max_y + slot_half_height or false,
    }
  end

  return {
    offset = offset,
    bounded_offset = bounded_offset,
    max_offset = max_offset,
    first_index = first_index,
    row_offset = row_offset,
    slots = slots,
  }
end

return M
