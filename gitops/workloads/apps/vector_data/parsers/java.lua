-- java.lua
-- Returns language rules for Java stacktraces.

local JAVA_RULES = {
  name = "java",

  -- Java stacktrace usually starts with one of:
  --   Exception in thread "main" java.lang.NullPointerException: ...
  --   java.lang.RuntimeException: ...
  --   Caused by: java.lang.IllegalStateException: ...
  start = {
    function(s)
      return s:match('^Exception in thread ".-" [%w_%.%$]+%s*:') ~= nil
          or s:match('^Exception in thread ".-" [%w_%.%$]+$') ~= nil
    end,
    function(s)
      -- Common: "java.lang.XxxException:" / "com.foo.BarException:"
      return s:match('^[%w_%.%$]+Exception%s*:') ~= nil
          or s:match('^[%w_%.%$]+Error%s*:') ~= nil
    end,
    function(s)
      -- "Caused by: ..."
      return s:match('^Caused by:%s+[%w_%.%$]+%s*:') ~= nil
          or s:match('^Caused by:%s+[%w_%.%$]+$') ~= nil
    end,
  },

  -- Java stack frames:
  --   \tat com.example.App.main(App.java:14)
  --   \tat java.base/java.lang.Thread.run(Thread.java:833)
  inside = {
    function(s)
      return s:match("^%s*at%s+[%w_%.%$]+%b().*$") ~= nil
    end,
    function(s)
      -- "... N more"
      return s:match("^%s*%.%.%.%s+%d+%s+more%s*$") ~= nil
    end,
    function(s)
      -- nested cause line also considered inside (keeps chain together)
      return s:match("^Caused by:%s+[%w_%.%$]+") ~= nil
    end,
    function(s)
      -- Suppressed: ...
      return s:match("^Suppressed:%s+[%w_%.%$]+") ~= nil
    end,
  },

  -- No single reliable finish line; end on boundary.
  finish = {},

  buffer = { max_lines = 600 },

  -- Print when boundary is hit (next non-stack line)
  emit_on_boundary = true,
}

return JAVA_RULES
