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

  local springy = scroll.create({
    min = 0,
    max = 300,
    offset = 0,
    drag_scale = 1,
    overscroll_limit = 80,
    overscroll_resistance = 0.35,
    spring_stiffness = 150,
    spring_damping = 15,
    inertia_damping = 5.5,
    max_velocity = 1450,
    epsilon = 0.45,
  })

  scroll.begin_drag(springy, 0, { frame = 0 })
  changed = scroll.drag_to(springy, -120, { frame = 2 })
  assert.equal(changed, true, "springy drag should report a rubber-band movement")
  assert.equal(springy.offset, -42, "springy drag should allow resisted overscroll below min")
  assert.equal(springy.velocity, -1260, "springy drag should record frame-based release velocity")
  scroll.end_drag(springy)

  local last_offset = springy.offset
  local settled = false
  for _ = 1, 120 do
    changed = scroll.update(springy, 1 / 60)
    if changed then
      assert.equal(springy.offset >= -80, true, "spring update should keep min overscroll bounded")
      assert.equal(springy.offset <= 380, true, "spring update should keep max overscroll bounded")
      last_offset = springy.offset
    end
    if springy.offset == 0 and springy.velocity == 0 then
      settled = true
      break
    end
  end
  assert.equal(settled, true, "spring update should settle an overscrolled list back to min")
  assert.equal(last_offset <= 0, true, "spring update should approach the min edge from overscroll")

  springy = scroll.create({
    min = 0,
    max = 300,
    offset = 120,
    velocity = 900,
    max_velocity = 1450,
    inertia_damping = 5.5,
    epsilon = 0.45,
  })
  changed = scroll.update(springy, 1 / 60)
  assert.equal(changed, true, "in-range velocity should continue inertial scrolling")
  assert.equal(springy.offset > 120, true, "inertia should move the offset while inside bounds")
  assert.equal(springy.velocity < 900, true, "inertia should damp velocity each frame")

  local layout = scroll.layout({
    offset = 150,
    item_count = 24,
    slot_count = 6,
    row_spacing = 132,
    top = 291,
    min_y = -342,
    max_y = 342,
    slot_half_height = 63,
  })
  assert.equal(layout.max_offset, 2376, "layout should compute max offset from hidden rows")
  assert.equal(layout.first_index, 2, "layout should start at the first partially hidden row")
  assert.equal(layout.slots[1].item_index, 2, "layout should map slot one to the second item")
  assert.equal(layout.slots[1].visible, true, "layout should keep a row visible until fully clipped")
  assert.equal(layout.slots[6].visible, true, "layout should keep the bottom row visible while partially clipped")
end

return run
