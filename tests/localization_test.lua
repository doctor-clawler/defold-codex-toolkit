local assert = require("tests.assert")

local function run()
  package.loaded["defold_helper.localization"] = nil
  local localization = require("defold_helper.localization")

  local csv = table.concat({
    "key,en,ko,comment",
    "ui.title,Mini Survivor,미니 서바이버,plain value",
    "ui.shop.title,\"Inventory, Shop\",인벤토리 상점,quoted comma",
    "ui.greeting,\"Hello, {name}\",\"안녕, {name}\",placeholder",
    "ui.quote,\"Use \"\"Lock\"\"\",Lock을 사용,double quote",
    "",
  }, "\n")

  local bundle = localization.from_csv(csv, {
    default_language = "en",
    fallback_language = "en",
  })

  assert.equal(bundle:language(), "en", "bundle should keep the configured default language")
  assert.equal(bundle:text("ui.title"), "Mini Survivor", "text should use current language")
  assert.equal(bundle:text("ui.shop.title"), "Inventory, Shop", "csv parser should preserve quoted commas")
  assert.equal(bundle:text("ui.greeting", { name = "Ada" }), "Hello, Ada", "text should interpolate current language")
  assert.equal(bundle:text("ui.greeting", "ko", { name = "민" }), "안녕, 민", "text should accept explicit language")
  assert.equal(bundle:text("ui.quote"), "Use \"Lock\"", "csv parser should preserve escaped double quotes")
  assert.equal(bundle:text("missing.key"), "missing.key", "missing keys should fall back to the key")
  assert.equal(bundle:text("ui.title", "ja"), "Mini Survivor", "missing language should use fallback language")

  bundle:set_language("ko")
  assert.equal(bundle:language(), "ko", "set_language should update current language")
  assert.equal(bundle:text("ui.title"), "미니 서바이버", "text should use updated current language")
  assert.equal(bundle:has("ui.title", "ko"), true, "has should report existing localized keys")
  assert.equal(bundle:has("ui.title", "ja"), false, "has should report missing language values")

  local resource_sys = {
    load_resource = function(path)
      assert.equal(path, "/assets/localization.csv", "from_resource should request the configured resource path")
      return csv
    end,
  }
  local resource_bundle = localization.from_resource("/assets/localization.csv", {
    sys = resource_sys,
    default_language = "ko",
    fallback_language = "en",
  })
  assert.equal(resource_bundle:text("ui.shop.title"), "인벤토리 상점", "from_resource should build a bundle from sys.load_resource")
end

return run
