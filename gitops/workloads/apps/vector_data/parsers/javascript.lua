-- javascript.lua
-- Returns language rules for JavaScript/Node.js (V8) stack traces.

local JS_RULES = {
  name = "javascript",

  -- Start examples:
  --   TypeError: Cannot read properties of undefined (reading 'x')
  --   ReferenceError: foo is not defined
  --   Error: something bad happened
  --   UnhandledPromiseRejectionWarning: Error: boom
  --   AggregateError: ...
  start = {
    function(s)
      -- Common Error types ending with Error:
      -- TypeError, ReferenceError, SyntaxError, RangeError, URIError, EvalError, AggregateError, Error
      return s:match("^[%w_%.]*Error%s*:") ~= nil
    end,
    function(s)
      -- Older Node formats
      return s:match("^UnhandledPromiseRejectionWarning:%s+") ~= nil
          or s:match("^UnhandledPromiseRejection:%s+") ~= nil
          or s:match("^DeprecationWarning:%s+") ~= nil
    end,
  },

  -- Inside examples:
  --   at Object.<anonymous> (/app/index.js:10:5)
  --   at Module._compile (node:internal/modules/cjs/loader:1234:14)
  --   at processTicksAndRejections (node:internal/process/task_queues:96:5)
  --   at /app/index.mjs:12:3
  inside = {
    function(s)
      -- "at ..." frame with file:line:col somewhere
      -- Require line:col to avoid matching Java "at com.foo.Bar(...)" frames.
      return s:match("^%s*at%s+.+:%d+:%d+%)%s*$") ~= nil
          or s:match("^%s*at%s+.+:%d+:%d+%s*$") ~= nil
    end,
    function(s)
      -- node:internal frames
      return s:match("^%s*at%s+.+%s+%(%s*node:internal/.+:%d+:%d+%)%s*$") ~= nil
          or s:match("^%s*at%s+node:internal/.+:%d+:%d+%s*$") ~= nil
          or s:match("^%s*at%s+.+%s+%(%s*node:.+:%d+:%d+%)%s*$") ~= nil
    end,
    function(s)
      -- Some stacks include "    at async ..." frames
      return s:match("^%s*at%s+async%s+.+:%d+:%d+%s*$") ~= nil
          or s:match("^%s*at%s+async%s+.+:%d+:%d+%)%s*$") ~= nil
    end,
    function(s)
      -- Optional "Caused by:" style sometimes appears in wrapped errors (rare, but harmless)
      return s:match("^%s*Caused by:%s+.+$") ~= nil
    end,
  },

  -- No reliable finish line across all Node versions; end on boundary.
  finish = {},

  buffer = { max_lines = 600 },

  -- JS: print when boundary is hit (next non-stack line)
  emit_on_boundary = true,
}

return JS_RULES
