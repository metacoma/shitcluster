import regex


is_focus = lambda name : str -> bool {
  regex.match(name, '^\*')
}

win_focus_n = lambda windows : [Window] -> int {
  len([w for w in windows if is_focus(w.name)])
}

schema Tmux:
  name: str
  env?: Env
  workdir?: str = "~"
  windows: [Window]
  before?: str|[str]
  check:
    win_focus_n(windows) < 2, "error"

schema Window:
  name: str
  layout?: str
  env?: Env
  workdir?: str = "~"
  options?: {str:str}
  options_after?: {str:str}
  suppress_history?: bool
  index?: int
  before?: str|[str]
  panes: [str|[str]]

schema Env:
  [variable: str]: str
  check:
    regex.match(variable, "^[_a-zA-Z][_a-zA-Z0-9]*$"), errors.InvalidShellVariable(variable)

errors = {
  InvalidShellVariable = lambda variable: str -> str {"Invalid POSIX shell variable name: '${variable}'. Names must start with a letter or underscore and contain only letters, digits, and underscores."}
}
