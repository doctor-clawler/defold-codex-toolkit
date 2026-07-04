local assert = require("tests.assert")

local function read_file(path)
  local handle = io.open(path, "r")
  if not handle then
    return ""
  end
  local content = handle:read("*a")
  handle:close()
  return content
end

local function run()
  local game_project = read_file("game.project")
  assert.contains(game_project, "[library]", "helper repo should declare Defold library metadata")
  assert.contains(game_project, "include_dirs = defold_helper", "library metadata should expose only the defold_helper namespace")

  local docs = read_file("docs/runtime-library.md")
  assert.contains(docs, "require(\"defold_helper.score_records\")", "adoption docs should show score_records require path")
  assert.contains(docs, "dependencies", "adoption docs should document Defold dependency configuration")
end

return run
