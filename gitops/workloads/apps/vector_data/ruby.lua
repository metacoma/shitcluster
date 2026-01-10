local RUBY_RULES = {
  name = "ruby",

  -- Ruby stacktrace start:
  -- 1) file.rb:12:in `foo': message (NoMethodError)
  -- 2) file.rb:12:in `foo': message (RuntimeError)
  -- 3) NoMethodError: message
  -- 4) RuntimeError: message
  --
  -- IMPORTANT: do NOT treat arbitrary "(...)" at end as Ruby (that matches Go).
  start = {
    -- Ruby "file.rb:line:in `method': ... (ErrorClass)"
    function(s)
      return s:match("%.rb:%d+:in%s+`.-':") ~= nil
         and s:match("%([%w_:]+%w+Error%)%s*$") ~= nil
            or s:match("%([%w_:]+%w+Exception%)%s*$") ~= nil
            or s:match("%([%w_:]+%w+Error%)") ~= nil
            or s:match("%([%w_:]+%w+Exception%)") ~= nil
    end,

    -- Ruby "ErrorClass: message" (with optional module nesting ::)
    function(s)
      return s:match("^[%w_:]+Error%s*:") ~= nil
          or s:match("^[%w_:]+Exception%s*:") ~= nil
    end,

    -- Rails-ish: "ErrorClass (message)"  (still strict: must end with Error/Exception)
    function(s)
      return s:match("^[%w_:]+Error%s*%(.+%)%s*$") ~= nil
          or s:match("^[%w_:]+Exception%s*%(.+%)%s*$") ~= nil
    end,
  },

  -- Ruby backtrace lines:
  inside = {
    -- "from ..." lines (often indented)
    function(s)
      return s:match("^%s*from%s+") ~= nil
    end,
    -- Ruby frame line: "...rb:12:in `method'"
    function(s)
      return s:match("%.rb:%d+:in%s+`.-'") ~= nil
    end,
  },

  finish = {},

  buffer = { max_lines = 500 },

  -- Ruby: print when we hit a non-backtrace boundary (since no reliable finish)
  emit_on_boundary = true,
}

return RUBY_RULES
