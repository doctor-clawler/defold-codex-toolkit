local M = {}

local DEFAULT_KEY_COLUMN = "key"
local DEFAULT_FALLBACK_LANGUAGE = "en"
local DEFAULT_LANGUAGES = {
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
local DEFAULT_LANGUAGE_DISPLAY_NAMES = {
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
local LANGUAGE_ALIASES = {
  ko = "ko-KR",
  kr = "ko-KR",
  ja = "ja-JP",
  jp = "ja-JP",
  zh = "zh-CN",
  ["zh-Hans"] = "zh-CN",
  ["zh-Hant"] = "zh-TW",
  de = "de-DE",
  fr = "fr-FR",
  es = "es-ES",
  ["es-LA"] = "es-419",
  pt = "pt-BR",
  it = "it-IT",
  ru = "ru-RU",
  tr = "tr-TR",
  pl = "pl-PL",
  hi = "hi-IN",
  nl = "nl-NL",
}
local DEFAULT_LANGUAGE_VARIATIONS = {
  { code = "ko-KR", name = DEFAULT_LANGUAGE_DISPLAY_NAMES["ko-KR"], aliases = { "ko", "kr" } },
  { code = "en", name = DEFAULT_LANGUAGE_DISPLAY_NAMES.en, aliases = {} },
  { code = "ja-JP", name = DEFAULT_LANGUAGE_DISPLAY_NAMES["ja-JP"], aliases = { "ja", "jp" } },
  { code = "zh-CN", name = DEFAULT_LANGUAGE_DISPLAY_NAMES["zh-CN"], aliases = { "zh", "zh-Hans" } },
  { code = "zh-TW", name = DEFAULT_LANGUAGE_DISPLAY_NAMES["zh-TW"], aliases = { "zh-Hant" } },
  { code = "de-DE", name = DEFAULT_LANGUAGE_DISPLAY_NAMES["de-DE"], aliases = { "de" } },
  { code = "fr-FR", name = DEFAULT_LANGUAGE_DISPLAY_NAMES["fr-FR"], aliases = { "fr" } },
  { code = "es-419", name = DEFAULT_LANGUAGE_DISPLAY_NAMES["es-419"], aliases = { "es-LA" } },
  { code = "es-ES", name = DEFAULT_LANGUAGE_DISPLAY_NAMES["es-ES"], aliases = { "es" } },
  { code = "pt-BR", name = DEFAULT_LANGUAGE_DISPLAY_NAMES["pt-BR"], aliases = { "pt" } },
  { code = "it-IT", name = DEFAULT_LANGUAGE_DISPLAY_NAMES["it-IT"], aliases = { "it" } },
  { code = "ru-RU", name = DEFAULT_LANGUAGE_DISPLAY_NAMES["ru-RU"], aliases = { "ru" } },
  { code = "tr-TR", name = DEFAULT_LANGUAGE_DISPLAY_NAMES["tr-TR"], aliases = { "tr" } },
  { code = "pl-PL", name = DEFAULT_LANGUAGE_DISPLAY_NAMES["pl-PL"], aliases = { "pl" } },
  { code = "th", name = DEFAULT_LANGUAGE_DISPLAY_NAMES.th, aliases = {} },
  { code = "id", name = DEFAULT_LANGUAGE_DISPLAY_NAMES.id, aliases = {} },
  { code = "vi", name = DEFAULT_LANGUAGE_DISPLAY_NAMES.vi, aliases = {} },
  { code = "ar", name = DEFAULT_LANGUAGE_DISPLAY_NAMES.ar, aliases = {} },
  { code = "hi-IN", name = DEFAULT_LANGUAGE_DISPLAY_NAMES["hi-IN"], aliases = { "hi" } },
  { code = "nl-NL", name = DEFAULT_LANGUAGE_DISPLAY_NAMES["nl-NL"], aliases = { "nl" } },
}
local DEFAULT_LANGUAGE_VARIATIONS_BY_CODE = {}
for _, variation in ipairs(DEFAULT_LANGUAGE_VARIATIONS) do
  DEFAULT_LANGUAGE_VARIATIONS_BY_CODE[variation.code] = variation
end
local METADATA_COLUMNS = {
  comment = true,
  comments = true,
  note = true,
  notes = true,
}

local function strip_bom(text)
  if string.sub(text, 1, 3) == "\239\187\191" then
    return string.sub(text, 4)
  end
  return text
end

local function is_metadata_column(name)
  if name == nil then
    return true
  end
  local lowered = string.lower(name)
  return lowered == "" or string.sub(lowered, 1, 1) == "#" or METADATA_COLUMNS[lowered] == true
end

local function parse_csv(text)
  text = strip_bom(tostring(text or ""))

  local rows = {}
  local row = {}
  local field = {}
  local in_quotes = false
  local i = 1
  local length = #text

  local function finish_field()
    row[#row + 1] = table.concat(field)
    field = {}
  end

  local function finish_row()
    finish_field()
    rows[#rows + 1] = row
    row = {}
  end

  while i <= length do
    local char = string.sub(text, i, i)

    if in_quotes then
      if char == "\"" then
        local next_char = string.sub(text, i + 1, i + 1)
        if next_char == "\"" then
          field[#field + 1] = "\""
          i = i + 1
        else
          in_quotes = false
        end
      else
        field[#field + 1] = char
      end
    else
      if char == "\"" then
        in_quotes = true
      elseif char == "," then
        finish_field()
      elseif char == "\n" then
        finish_row()
      elseif char == "\r" then
        local next_char = string.sub(text, i + 1, i + 1)
        if next_char == "\n" then
          i = i + 1
        end
        finish_row()
      else
        field[#field + 1] = char
      end
    end

    i = i + 1
  end

  if #field > 0 or #row > 0 or length > 0 then
    finish_row()
  end

  return rows
end

local function is_empty_row(row)
  for index = 1, #row do
    if row[index] ~= "" then
      return false
    end
  end
  return true
end

local function index_header(header)
  local by_name = {}
  for index = 1, #header do
    by_name[header[index]] = index
  end
  return by_name
end

local function resolve_language_columns(header, options, key_column_index)
  if type(options.languages) == "table" then
    local result = {}
    local header_index = index_header(header)
    for _, language in ipairs(options.languages) do
      local column_index = header_index[language]
      if column_index then
        result[#result + 1] = {
          language = language,
          index = column_index,
        }
      end
    end
    return result
  end

  local result = {}
  for index = 1, #header do
    local name = header[index]
    if index ~= key_column_index and not is_metadata_column(name) then
      result[#result + 1] = {
        language = name,
        index = index,
      }
    end
  end
  return result
end

local function interpolate(text, params)
  if type(params) ~= "table" then
    return text
  end

  return (text:gsub("{([%w_%.%-]+)}", function(name)
    local value = params[name]
    if value == nil then
      return "{" .. name .. "}"
    end
    return tostring(value)
  end))
end

local function copy_array(values)
  local result = {}
  for index = 1, #values do
    result[index] = values[index]
  end
  return result
end

local function copy_map(values)
  local result = {}
  for key, value in pairs(values) do
    result[key] = value
  end
  return result
end

local function has_language(languages, language)
  if type(languages) ~= "table" or type(language) ~= "string" or language == "" then
    return false
  end
  for index = 1, #languages do
    if languages[index] == language then
      return true
    end
  end
  return false
end

local function normalize_language_for(languages, language)
  if type(language) ~= "string" or language == "" then
    return language
  end
  if has_language(languages, language) then
    return language
  end
  local alias = LANGUAGE_ALIASES[language]
  if alias and has_language(languages, alias) then
    return alias
  end
  return language
end

local function language_display_name_for(languages, language)
  local normalized = normalize_language_for(languages or DEFAULT_LANGUAGES, language)
  return DEFAULT_LANGUAGE_DISPLAY_NAMES[normalized] or tostring(normalized or "")
end

local function language_variations_for(languages)
  local result = {}
  for index = 1, #languages do
    local language = languages[index]
    local variation = DEFAULT_LANGUAGE_VARIATIONS_BY_CODE[language]
    result[index] = {
      code = language,
      name = language_display_name_for(languages, language),
      aliases = variation and copy_array(variation.aliases or {}) or {},
    }
  end
  return result
end

local function copy_language_variations(values)
  local result = {}
  for index = 1, #values do
    local value = values[index]
    result[index] = {
      code = value.code,
      name = value.name,
      aliases = copy_array(value.aliases or {}),
    }
  end
  return result
end

local function make_bundle(entries, languages, options)
  local default_language = normalize_language_for(languages, options.default_language or languages[1] or DEFAULT_FALLBACK_LANGUAGE)
  local fallback_language = normalize_language_for(languages, options.fallback_language or default_language or languages[1] or DEFAULT_FALLBACK_LANGUAGE)
  local bundle = {
    _entries = entries,
    _languages = languages,
    _language = default_language,
    _fallback_language = fallback_language,
  }

  function bundle:language()
    return self._language
  end

  function bundle:set_language(language)
    if type(language) == "string" and language ~= "" then
      self._language = normalize_language_for(self._languages, language)
    end
    return self
  end

  function bundle:fallback_language()
    return self._fallback_language
  end

  function bundle:set_fallback_language(language)
    if type(language) == "string" and language ~= "" then
      self._fallback_language = normalize_language_for(self._languages, language)
    end
    return self
  end

  function bundle:available_languages()
    return copy_array(self._languages)
  end

  function bundle:language_display_name(language)
    return language_display_name_for(self._languages, language or self._language)
  end

  function bundle:language_variations()
    return language_variations_for(self._languages)
  end

  function bundle:has(key, language)
    local entry = self._entries[key]
    if not entry then
      return false
    end
    local value = entry[normalize_language_for(self._languages, language or self._language)]
    return value ~= nil and value ~= ""
  end

  function bundle:text(key, language_or_params, params)
    local language = self._language
    if type(language_or_params) == "string" then
      language = normalize_language_for(self._languages, language_or_params)
    elseif type(language_or_params) == "table" and params == nil then
      params = language_or_params
    end

    local entry = self._entries[key]
    if not entry then
      return tostring(key)
    end

    local value = entry[language]
    if value == nil or value == "" then
      value = entry[self._fallback_language]
    end
    if value == nil or value == "" then
      value = tostring(key)
    end

    return interpolate(value, params)
  end

  function bundle:raw(key, language)
    local entry = self._entries[key]
    if not entry then
      return nil
    end
    return entry[normalize_language_for(self._languages, language or self._language)]
  end

  return bundle
end

function M.default_languages()
  return copy_array(DEFAULT_LANGUAGES)
end

function M.default_language_display_names()
  return copy_map(DEFAULT_LANGUAGE_DISPLAY_NAMES)
end

function M.default_language_variations()
  return copy_language_variations(DEFAULT_LANGUAGE_VARIATIONS)
end

function M.normalize_language(language, languages)
  return normalize_language_for(languages or DEFAULT_LANGUAGES, language)
end

function M.language_display_name(language, languages)
  return language_display_name_for(languages or DEFAULT_LANGUAGES, language)
end

function M.parse_csv(text)
  return parse_csv(text)
end

function M.from_rows(rows, options)
  options = options or {}

  local header
  local start_index = 1
  for index = 1, #rows do
    if not is_empty_row(rows[index]) then
      header = rows[index]
      start_index = index + 1
      break
    end
  end

  if not header then
    return make_bundle({}, {}, options)
  end

  local key_column = options.key_column or DEFAULT_KEY_COLUMN
  local header_index = index_header(header)
  local key_column_index = header_index[key_column] or 1
  local language_columns = resolve_language_columns(header, options, key_column_index)
  local entries = {}
  local languages = {}

  for _, column in ipairs(language_columns) do
    languages[#languages + 1] = column.language
  end

  for row_index = start_index, #rows do
    local row = rows[row_index]
    if not is_empty_row(row) then
      local key = row[key_column_index]
      if key and key ~= "" then
        local entry = entries[key] or {}
        entries[key] = entry

        for _, column in ipairs(language_columns) do
          local value = row[column.index]
          if value ~= nil and value ~= "" then
            entry[column.language] = value
          end
        end
      end
    end
  end

  return make_bundle(entries, languages, options)
end

function M.from_csv(text, options)
  return M.from_rows(parse_csv(text), options)
end

function M.from_resource(path, options)
  options = options or {}
  local sys_api = options.sys or rawget(_G, "sys")
  if not sys_api or type(sys_api.load_resource) ~= "function" then
    return M.from_csv("", options)
  end

  local ok, text = pcall(sys_api.load_resource, path)
  if not ok or text == nil then
    return M.from_csv("", options)
  end

  return M.from_csv(text, options)
end

return M
