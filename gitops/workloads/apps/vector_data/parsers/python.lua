local PY_RULES = {
  name = "python",

  start = {
    function(s) return s == "Traceback (most recent call last):" end,
  },

  inside = {
    function(s) return s:match('^%s*File%s+".-"%s*,%s*line%s+%d+%s*,%s*in%s+.+$') ~= nil end,
    function(s) return s:match("^%s+.+$") ~= nil end,
    function(s)
      return s == "During handling of the above exception, another exception occurred:"
          or s == "The above exception was the direct cause of the following exception:"
    end,
    function(s) return s:match("^ExceptionGroup%s*:") ~= nil end,
    function(s) return s:match("^[%|%+%-]+") ~= nil end,
  },

  finish = {
    function(s)
      return s:match("^[%w_%.]+Error%s*:") ~= nil
          or s:match("^[%w_%.]+Exception%s*:") ~= nil
          or s:match("^[%w_%.]+Error%s*$") ~= nil
          or s:match("^[%w_%.]+Exception%s*$") ~= nil
    end,
  },

  buffer = { max_lines = 300 },

  emit_on_boundary = false,
}

return PY_RULES
