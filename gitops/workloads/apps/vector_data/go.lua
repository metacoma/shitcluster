-- go.lua
-- Returns language rules for Go panic stack traces.

local GO_RULES = {
  name = "go",

  -- Go panic start:
  --   panic: ...
  --   fatal error: ...
  start = {
    function(s)
      return s:match("^panic:%s+") ~= nil
          or s:match("^fatal error:%s+") ~= nil
    end,
  },

  -- Go stack trace lines:
  inside = {
    -- signal line
    function(s)
      return s:match("^%[signal%s+SIG[%w%d]+:") ~= nil
    end,
    -- goroutine header
    function(s)
      return s:match("^goroutine%s+%d+%s+%[") ~= nil
    end,
    -- function call line, e.g. "main.handleRequest(0x0)"
    function(s)
      -- Avoid matching Ruby/Java: require a dot and trailing "(...)" with no ":in `...`" etc.
      return s:match("^[%w_%.]+%b()%s*$") ~= nil
         and s:match(":in%s+`") == nil
         and s:match("^%s*at%s+") == nil
    end,
    -- file:line +offset line, e.g. "\t/app/main.go:42 +0x2c"
    function(s)
      return s:match("^%s*/.+%.go:%d+%s+%+0x[%da-fA-F]+%s*$") ~= nil
    end,
    -- optional blank line inside panic output
    function(s)
      return s == ""
    end,
  },

  finish = {},

  buffer = { max_lines = 600 },

  -- Go: print when boundary is hit
  emit_on_boundary = true,
}

return GO_RULES
