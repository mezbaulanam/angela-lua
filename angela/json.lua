--
-- json.lua — Pure Lua JSON parser and encoder for Lua 5.1+ / 5.4
--
local json = {}

local null = {}
json.null = null

-- Escaped character map
local escape_char_map = {
  ["\\"] = "\\\\",
  ["\""] = "\\\"",
  ["\b"] = "\\b",
  ["\f"] = "\\f",
  ["\n"] = "\\n",
  ["\r"] = "\\r",
  ["\t"] = "\\t",
}

local function escape_char(c)
  return escape_char_map[c] or string.format("\\u%04x", string.byte(c))
end

local function encode_string(val)
  return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
end

local function is_array(tbl)
  if type(tbl) ~= "table" then return false end
  local count = 0
  for _ in pairs(tbl) do
    count = count + 1
  end
  for i = 1, count do
    if tbl[i] == nil then
      return false
    end
  end
  return count > 0
end

local function encode_value(val)
  local t = type(val)
  if val == nil or val == null then
    return "null"
  elseif t == "boolean" then
    return val and "true" or "false"
  elseif t == "number" then
    if val ~= val then return "null" end -- NaN
    if val >= math.huge or val <= -math.huge then return "null" end
    if math.type and math.type(val) == "integer" then
      return string.format("%d", val)
    else
      return string.format("%.14g", val)
    end
  elseif t == "string" then
    return encode_string(val)
  elseif t == "table" then
    if hasattr_to_dict and val.to_dict then
      return encode_value(val:to_dict())
    end
    -- Check if array
    if is_array(val) then
      local parts = {}
      for i, item in ipairs(val) do
        parts[i] = encode_value(item)
      end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      local parts = {}
      local n = 0
      for k, v in pairs(val) do
        if type(k) == "string" or type(k) == "number" then
          n = n + 1
          parts[n] = encode_string(tostring(k)) .. ":" .. encode_value(v)
        end
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  else
    return "null"
  end
end

function json.encode(val)
  return encode_value(val)
end

-- ==================== DECODER ====================
local function skip_whitespace(str, idx)
  local len = #str
  while idx <= len do
    local b = str:byte(idx)
    if b == 32 or b == 9 or b == 10 or b == 13 then
      idx = idx + 1
    else
      break
    end
  end
  return idx
end

local decode_value

local function decode_string(str, idx)
  idx = idx + 1 -- skip opening quote
  local start_idx = idx
  local parts = {}
  local len = #str
  while idx <= len do
    local b = str:byte(idx)
    if b == 34 then -- quote
      local s = str:sub(start_idx, idx - 1)
      table.insert(parts, s)
      return table.concat(parts), idx + 1
    elseif b == 92 then -- backslash
      local s = str:sub(start_idx, idx - 1)
      table.insert(parts, s)
      local next_b = str:byte(idx + 1)
      if next_b == 34 then table.insert(parts, '"')
      elseif next_b == 92 then table.insert(parts, '\\')
      elseif next_b == 47 then table.insert(parts, '/')
      elseif next_b == 98 then table.insert(parts, '\b')
      elseif next_b == 102 then table.insert(parts, '\f')
      elseif next_b == 110 then table.insert(parts, '\n')
      elseif next_b == 114 then table.insert(parts, '\r')
      elseif next_b == 116 then table.insert(parts, '\t')
      elseif next_b == 117 then
        local hex = str:sub(idx + 2, idx + 5)
        local cp = tonumber(hex, 16) or 63
        if cp < 128 then
          table.insert(parts, string.char(cp))
        else
          table.insert(parts, utf8 and utf8.char and utf8.char(cp) or "?")
        end
        idx = idx + 4
      end
      idx = idx + 2
      start_idx = idx
    else
      idx = idx + 1
    end
  end
  error("Unterminated string at position " .. start_idx)
end

local function decode_number(str, idx)
  local m = str:match("^-?%d+%.?%d*[eE]?[+-]?%d*", idx)
  if not m or #m == 0 then
    error("Invalid number at position " .. idx)
  end
  local num = tonumber(m)
  if not num then
    error("Invalid number at position " .. idx)
  end
  return num, idx + #m
end

local function decode_array(str, idx)
  idx = idx + 1 -- skip '['
  local arr = {}
  idx = skip_whitespace(str, idx)
  if str:byte(idx) == 93 then -- ']'
    return arr, idx + 1
  end
  local i = 1
  while true do
    local val
    val, idx = decode_value(str, idx)
    arr[i] = val
    i = i + 1
    idx = skip_whitespace(str, idx)
    local b = str:byte(idx)
    if b == 44 then -- ','
      idx = skip_whitespace(str, idx + 1)
    elseif b == 93 then -- ']'
      return arr, idx + 1
    else
      error("Expected ',' or ']' in array at position " .. idx)
    end
  end
end

local function decode_object(str, idx)
  idx = idx + 1 -- skip '{'
  local obj = {}
  idx = skip_whitespace(str, idx)
  if str:byte(idx) == 125 then -- '}'
    return obj, idx + 1
  end
  while true do
    if str:byte(idx) ~= 34 then
      error("Expected string key in object at position " .. idx)
    end
    local key
    key, idx = decode_string(str, idx)
    idx = skip_whitespace(str, idx)
    if str:byte(idx) ~= 58 then -- ':'
      error("Expected ':' after key at position " .. idx)
    end
    idx = skip_whitespace(str, idx + 1)
    local val
    val, idx = decode_value(str, idx)
    obj[key] = val
    idx = skip_whitespace(str, idx)
    local b = str:byte(idx)
    if b == 44 then -- ','
      idx = skip_whitespace(str, idx + 1)
    elseif b == 125 then -- '}'
      return obj, idx + 1
    else
      error("Expected ',' or '}' in object at position " .. idx)
    end
  end
end

decode_value = function(str, idx)
  idx = skip_whitespace(str, idx)
  local b = str:byte(idx)
  if not b then
    error("Unexpected end of JSON input")
  end
  if b == 34 then -- '"'
    return decode_string(str, idx)
  elseif b == 123 then -- '{'
    return decode_object(str, idx)
  elseif b == 91 then -- '['
    return decode_array(str, idx)
  elseif b == 116 and str:sub(idx, idx + 3) == "true" then
    return true, idx + 4
  elseif b == 102 and str:sub(idx, idx + 4) == "false" then
    return false, idx + 5
  elseif b == 110 and str:sub(idx, idx + 3) == "null" then
    return nil, idx + 4
  else
    return decode_number(str, idx)
  end
end

function json.decode(str)
  if type(str) ~= "string" then
    error("json.decode expects string, got " .. type(str))
  end
  local val, idx = decode_value(str, 1)
  idx = skip_whitespace(str, idx)
  if idx <= #str then
    error("Trailing characters after JSON input at position " .. idx)
  end
  return val
end

return json

