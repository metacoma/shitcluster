import regex

schema Session:
  session_name: str
  start_directory: str
  #windows: any
  windows: [Window]

schema Window:
  window_name: str
  environment?: Env
  panes?: [[any]]

schema Env:
  [variable: str]: str
  check:
    regex.match(variable, "^[_a-zA-Z][_a-zA-Z0-9]*$"), errors.InvalidShellVariable(variable)



errors = {
  InvalidShellVariable = lambda variable: str -> str {"Invalid POSIX shell variable name: '${variable}'. Names must start with a letter or underscore and contain only letters, digits, and underscores."}
}
