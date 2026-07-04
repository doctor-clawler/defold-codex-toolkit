local M = {}

local DEFAULT_KEY_COLUMN = "key"
local DEFAULT_FALLBACK_LANGUAGE = "en"
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

local function make_bundle(entries, languages, options)
  local bundle = {
    _entries = entries,
    _languages = languages,
    _language = options.default_language or languages[1] or DEFAULT_FALLBACK_LANGUAGE,
    _fallback_language = options.fallback_language or options.default_language or languages[1] or DEFAULT_FALLBACK_LANGUAGE,
  }

  function bundle:language()
    return self._language
  end

  function bundle:set_language(language)
    if type(language) == "string" and language ~= "" then
      self._language = language
    end
    return self
  end

  function bundle:fallback_language()
    return self._fallback_language
  end

  function bundle:set_fallback_language(language)
    if type(language) == "string" and language ~= "" then
      self._fallback_language = language
    end
    return self
  end

  function bundle:available_languages()
    return copy_array(self._languages)
  end

  function bundle:has(key, language)
    local entry = self._entries[key]
    if not entry then
      return false
    end
    local value = entry[language or self._language]
    return value ~= nil and value ~= ""
  end

  function bundle:text(key, language_or_params, params)
    local language = self._language
    if type(language_or_params) == "string" then
      language = language_or_params
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
    return entry[language or self._language]
  end

  return bundle
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
