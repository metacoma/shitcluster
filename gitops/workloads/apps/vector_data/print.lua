-- parsers/parser.lua
-- Минимальный отладочный процессор: печатает входящий event и message.

local function to_string(v)
  if v == nil then return "nil" end
  if type(v) == "string" then return v end
  return tostring(v)
end

local function get_log(event)
  if type(event) == "table" and type(event.log) == "table" then
    return event.log
  end
  return event
end

local function get_message(log)
  local m = log.message
  if m == nil then m = log.msg end
  if m == nil then m = log.line end
  if m == nil then m = "" end
  if type(m) ~= "string" then m = tostring(m) end
  return m
end

return function(event, emit)
end

