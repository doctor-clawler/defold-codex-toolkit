local M = {}

function M.equal(actual, expected, message)
  if actual ~= expected then
    error(message or string.format("expected %s, got %s", tostring(expected), tostring(actual)), 2)
  end
end

function M.contains(text, needle, message)
  if not string.find(text or "", needle, 1, true) then
    error(message or string.format("expected text to contain %s", tostring(needle)), 2)
  end
end

return M
