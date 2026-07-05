local assert = require("tests.assert")

local EXPECTED_DEFAULT_LANGUAGES = {
  "ko-KR",
  "en",
  "ja-JP",
  "zh-CN",
  "zh-TW",
  "de-DE",
  "fr-FR",
  "es-419",
  "es-ES",
  "pt-BR",
  "it-IT",
  "ru-RU",
  "tr-TR",
  "pl-PL",
  "th",
  "id",
  "vi",
  "ar",
  "hi-IN",
  "nl-NL",
}

local function run()
  package.loaded["defold_helper.localization"] = nil
  local localization = require("defold_helper.localization")

  assert.equal(table.concat(localization.default_languages(), ","), table.concat(EXPECTED_DEFAULT_LANGUAGES, ","), "default localization table should expose the project-wide locale list")
  assert.equal(localization.normalize_language("ko"), "ko-KR", "legacy Korean language code should normalize to ko-KR")
  assert.equal(localization.normalize_language("ja"), "ja-JP", "short Japanese language code should normalize to ja-JP")
  assert.equal(localization.normalize_language("es-419"), "es-419", "regional Spanish language code should remain stable")

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

  local locale_csv = table.concat({
    "key,ko-KR,en,ja-JP,comment",
    "ui.title,미니 서바이버,Mini Survivor,Mini Survivor,locale value",
    "ui.missing_japanese,한국어 값,English Value,,fallback value",
    "",
  }, "\n")
  local locale_bundle = localization.from_csv(locale_csv, {
    default_language = "ko",
    fallback_language = "en",
  })
  assert.equal(locale_bundle:language(), "ko-KR", "bundle should normalize default language aliases against available locales")
  assert.equal(locale_bundle:text("ui.title"), "미니 서바이버", "normalized default language should use the canonical locale column")
  assert.equal(table.concat(locale_bundle:available_languages(), ","), "ko-KR,en,ja-JP", "locale columns should preserve configured order")
  locale_bundle:set_language("ja")
  assert.equal(locale_bundle:language(), "ja-JP", "set_language should normalize aliases against available locales")
  assert.equal(locale_bundle:text("ui.missing_japanese"), "English Value", "missing canonical locale value should use fallback language")
  assert.equal(locale_bundle:has("ui.title", "ja"), true, "has should normalize explicit language aliases")
  assert.equal(locale_bundle:raw("ui.title", "ko"), "미니 서바이버", "raw should normalize explicit language aliases")

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
