-- rust.lua
-- Returns language rules for Rust panics/backtraces.

local RUST_RULES = {
  name = "rust",

  -- Rust panic start:
  --   thread 'main' panicked at '...', src/main.rs:10:5
  --   panicked at '...', src/main.rs:10:5
  start = {
    function(s)
      return s:match("^thread%s+'.-'%s+panicked%s+at%s+") ~= nil
          or s:match("^panicked%s+at%s+") ~= nil
    end,
  },

  -- Rust backtrace lines:
  --   0: mycrate::foo
  --      at src/main.rs:10
  --   1: std::panicking::begin_panic
  -- Some runtimes print "stack backtrace:" line as well.
  inside = {
    function(s)
      return s == "stack backtrace:"
          or s == "note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace"
    end,
    function(s)
      -- Frame index: "  0: ..." or "0: ..."
      return s:match("^%s*%d+:%s+.+$") ~= nil
    end,
    function(s)
      -- "at path:line" line
      return s:match("^%s*at%s+.+:%d+.*$") ~= nil
    end,
    function(s)
      -- "note:" lines often part of panic output
      return s:match("^note:%s+.+$") ~= nil
    end,
    function(s)
      return s == ""
    end,
  },

  finish = {},

  buffer = { max_lines = 600 },

  -- Rust: print when boundary is hit
  emit_on_boundary = true,
}

return RUST_RULES
