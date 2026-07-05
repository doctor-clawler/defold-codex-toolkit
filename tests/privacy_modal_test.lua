local assert = require("tests.assert")

local function run()
  package.loaded["defold_helper.privacy_modal"] = nil
  local privacy_modal = require("defold_helper.privacy_modal")

  local modal = privacy_modal.create({
    lines = {
      "No personal data is collected.",
      "Local progress stays on this device.",
    },
    button_bounds = {
      min_x = 470,
      max_x = 625,
      min_y = 970,
      max_y = 1045,
    },
  })

  assert.equal(privacy_modal.is_open(modal), false, "modal should start hidden")
  assert.equal(privacy_modal.line(modal, 1), "No personal data is collected.", "line should return configured text")
  assert.equal(privacy_modal.line(modal, 3), "", "missing lines should render as empty strings")
  assert.equal(privacy_modal.point_in_button(modal, 500, 1000, false), true, "visual fallback bounds should hit")
  assert.equal(privacy_modal.point_in_button(modal, 100, 1000, true), true, "explicit gui hit should win")
  assert.equal(privacy_modal.point_in_button(modal, 100, 1000, false), false, "outside point should miss")

  local open_action = privacy_modal.tap_action(modal, {
    frame = 10,
    last_handled_frame = -1,
    x = 500,
    y = 1000,
    button_hit = false,
  })
  assert.equal(open_action.kind, privacy_modal.ACTIONS.OPEN, "tap inside button bounds should open")
  assert.equal(privacy_modal.is_open(modal), true, "open action should update state")

  local duplicate_close = privacy_modal.tap_action(modal, {
    frame = 10,
    last_handled_frame = 10,
    x = 100,
    y = 100,
    button_hit = false,
  })
  assert.equal(duplicate_close.kind, privacy_modal.ACTIONS.BLOCK, "same-frame duplicate should be blocked")
  assert.equal(privacy_modal.is_open(modal), true, "same-frame duplicate must not close")

  local immediate_close = privacy_modal.tap_action(modal, {
    frame = 11,
    last_handled_frame = -1,
    x = 100,
    y = 100,
    button_hit = false,
  })
  assert.equal(immediate_close.kind, privacy_modal.ACTIONS.BLOCK, "next-frame duplicate close should be blocked")
  assert.equal(privacy_modal.is_open(modal), true, "next-frame duplicate must keep modal open")

  local close_action = privacy_modal.tap_action(modal, {
    frame = 12,
    last_handled_frame = -1,
    x = 100,
    y = 100,
    button_hit = false,
  })
  assert.equal(close_action.kind, privacy_modal.ACTIONS.CLOSE, "later tap while open should close")
  assert.equal(privacy_modal.is_open(modal), false, "close action should update state")
end

return run
