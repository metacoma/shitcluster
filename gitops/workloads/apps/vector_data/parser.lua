local function any_match(rules, s)
  if not rules then return false end
  for _, f in ipairs(rules) do
    if f(s) then return true end
  end
  return false
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
  if type(m) ~= "string" then
    m = tostring(m)
  end
  return m
end

local function get_kubernetes(log)
  local k = log.kubernetes
  if type(k) ~= "table" then k = {} end
  return k
end

local function stream_key(log)
  local k = get_kubernetes(log)
  return table.concat({
    k.namespace or "?",
    k.pod_name or "?",
    k.container_name or "?"
  }, "/")
end

local RULES = {
  require("parsers/python"),
--  require("parsers/ruby"),
--  require("parsers/java"),
--  require("parsers/go"),
--  require("parsers/rust"),
--  require("parsers/javascript"),
}

states = states or {}

local function state_of(key)
  local st = states[key]
  if not st then
    st = { active = false, rule = nil, lines = {}, meta = nil, k8s = nil }
    states[key] = st
  end
  return st
end

local function reset(st)
  st.active = false
  st.rule = nil
  st.lines = {}
  st.meta = nil
  st.k8s = nil
end

local function start_block(st, rule, log, msg)
  st.active = true
  st.rule = rule
  st.meta = {
    timestamp = log.timestamp or log["@timestamp"] or nil,
    stream = log.stream or nil,
  }
  st.k8s = get_kubernetes(log)
  st.lines = { msg }
end

local function emit_block(key, st, emit)
  local lang = (st.rule and st.rule.name) or "unknown"
  local out = {
    log = {
      message = table.concat(st.lines, "\n"),
      traceback = table.concat(st.lines, "\n"),
      language = lang,
      stream_key = key,
      kubernetes = st.k8s,
    }
  }

  if st.meta then
    if st.meta.timestamp ~= nil then out.log.timestamp = st.meta.timestamp end
    if st.meta.stream ~= nil then out.log.stream = st.meta.stream end
  end

  emit(out)
end

local function try_start_any(st, log, msg)
  for _, rule in ipairs(RULES) do
    if any_match(rule.start, msg) then
      start_block(st, rule, log, msg)
      return true
    end
  end
  return false
end

return function(event, emit)
  local log = get_log(event)
  local msg = get_message(log)
  if msg == "" then
    return
  end

  local key = stream_key(log)
  local st = state_of(key)

  if not st.active then
    try_start_any(st, log, msg)
    return
  end

  local rule = st.rule
  if not rule then
    reset(st)
    return
  end

  -- explicit finish?
  if any_match(rule.finish, msg) then
    st.lines[#st.lines + 1] = msg
    emit_block(key, st, emit)
    reset(st)
    return
  end

  -- continuation line?
  if any_match(rule.inside, msg) then
    st.lines[#st.lines + 1] = msg

    local max_lines = 300
    if rule.buffer and rule.buffer.max_lines then
      max_lines = rule.buffer.max_lines
    end

    if #st.lines >= max_lines then
      reset(st)
    end
    return
  end

  if rule.emit_on_boundary and #st.lines > 0 then
    emit_block(key, st, emit)
  end
  reset(st)

  try_start_any(st, log, msg)
end
