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
local EXPECTED_DEFAULT_LANGUAGE_NAMES = {
  ["ko-KR"] = "한국어",
  en = "English",
  ["ja-JP"] = "日本語",
  ["zh-CN"] = "简体中文",
  ["zh-TW"] = "繁體中文",
  ["de-DE"] = "Deutsch",
  ["fr-FR"] = "Français",
  ["es-419"] = "Español LATAM",
  ["es-ES"] = "Español",
  ["pt-BR"] = "Português BR",
  ["it-IT"] = "Italiano",
  ["ru-RU"] = "Русский",
  ["tr-TR"] = "Türkçe",
  ["pl-PL"] = "Polski",
  th = "ไทย",
  id = "Bahasa Indonesia",
  vi = "Tiếng Việt",
  ar = "العربية",
  ["hi-IN"] = "हिन्दी",
  ["nl-NL"] = "Nederlands",
}

local function run()
  package.loaded["defold_helper.localization"] = nil
  local localization = require("defold_helper.localization")

  assert.equal(table.concat(localization.default_languages(), ","), table.concat(EXPECTED_DEFAULT_LANGUAGES, ","), "default localization table should expose the project-wide locale list")
  assert.equal(localization.normalize_language("ko"), "ko-KR", "legacy Korean language code should normalize to ko-KR")
  assert.equal(localization.normalize_language("ja"), "ja-JP", "short Japanese language code should normalize to ja-JP")
  assert.equal(localization.normalize_language("es-419"), "es-419", "regional Spanish language code should remain stable")

  local variations = localization.default_language_variations()
  assert.equal(#variations, #EXPECTED_DEFAULT_LANGUAGES, "default language variations should match the shared locale count")
  assert.equal(table.concat(variations[1].aliases, ","), "ko,kr", "language variations should include legacy Korean aliases")
  assert.equal(table.concat(variations[8].aliases, ","), "es-LA", "language variations should include regional Spanish aliases")
  for index, language in ipairs(EXPECTED_DEFAULT_LANGUAGES) do
    assert.equal(variations[index].code, language, "language variation order should match default languages")
    assert.equal(variations[index].name, EXPECTED_DEFAULT_LANGUAGE_NAMES[language], "language variation should expose the fixed native display name")
    assert.equal(localization.language_display_name(language), EXPECTED_DEFAULT_LANGUAGE_NAMES[language], "language display name should expose the fixed native display name")
  end
  assert.equal(localization.language_display_name("ko"), "한국어", "Korean alias should display as 한국어")
  assert.equal(localization.language_display_name("ja"), "日本語", "Japanese alias should display as 日本語")
  assert.equal(localization.language_display_name("bogus"), "bogus", "unknown languages should fall back to their normalized code")
  variations[1].name = "Korean"
  assert.equal(localization.language_display_name("ko-KR"), "한국어", "language variation copies should not mutate shared display names")

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
  assert.equal(locale_bundle:language_display_name("ko"), "한국어", "bundle should expose fixed language display names independent of selected language")
  assert.equal(locale_bundle:language_display_name("ja"), "日本語", "bundle language display names should normalize aliases")
  local bundle_variations = locale_bundle:language_variations()
  assert.equal(#bundle_variations, 3, "bundle language variations should include only available languages")
  assert.equal(bundle_variations[1].code, "ko-KR", "bundle language variations should preserve bundle language order")
  assert.equal(bundle_variations[1].name, "한국어", "bundle language variations should expose native Korean name")
  assert.equal(table.concat(bundle_variations[1].aliases, ","), "ko,kr", "bundle language variations should expose legacy Korean aliases")
  assert.equal(bundle_variations[3].code, "ja-JP", "bundle language variations should normalize Japanese locale")
  assert.equal(bundle_variations[3].name, "日本語", "bundle language variations should expose native Japanese name")

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
