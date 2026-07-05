local assert = require("tests.assert")

local function run()
  package.loaded["defold_helper.scroll"] = nil
  local scroll = require("defold_helper.scroll")

  local state = scroll.create({
    min = 0,
    max = 100,
    offset = 30,
    wheel_step = 25,
  })

  assert.equal(state.offset, 30, "create should keep an in-range offset")
  assert.equal(scroll.ratio(state), 0.3, "ratio should normalize offset against min/max")

  local changed, next_offset, previous_offset = scroll.scroll_by(state, 90)
  assert.equal(changed, true, "scroll_by should report meaningful offset changes")
  assert.equal(previous_offset, 30, "scroll_by should return the previous offset")
  assert.equal(next_offset, 100, "scroll_by should clamp to max")
  assert.equal(state.offset, 100, "scroll_by should update the state offset")

  changed = scroll.scroll_by(state, 20)
  assert.equal(changed, false, "scroll_by should not report changes when already clamped")
  assert.equal(state.offset, 100, "scroll_by should keep max clamp")

  scroll.apply_wheel(state, "up")
  assert.equal(state.offset, 75, "wheel up should subtract one wheel step")
  scroll.apply_wheel(state, "down")
  assert.equal(state.offset, 100, "wheel down should add one wheel step")

  scroll.begin_drag(state, 10)
  changed = scroll.drag_to(state, 38)
  assert.equal(changed, false, "drag beyond max should remain unchanged when clamped")
  assert.equal(state.offset, 100, "drag beyond max should stay clamped")

  scroll.reset(state, { offset = 40 })
  scroll.begin_drag(state, 50)
  changed = scroll.drag_to(state, 10)
  assert.equal(changed, true, "dragging to a lower position should update offset")
  assert.equal(state.offset, 0, "dragging up should clamp to min")
  scroll.end_drag(state)
  assert.equal(state.dragging, false, "end_drag should clear dragging")

  scroll.configure(state, { min = 20, max = 60, offset = 80 })
  assert.equal(state.offset, 60, "configure should clamp a new offset")
  assert.equal(scroll.ratio(state), 1, "ratio should clamp at max")

  local inverted = scroll.create({ min = 100, max = 0, offset = 50 })
  assert.equal(inverted.min, 0, "create should normalize inverted min/max")
  assert.equal(inverted.max, 100, "create should normalize inverted max/min")
  assert.equal(inverted.offset, 50, "create should keep offset after normalizing range")
end

return run
