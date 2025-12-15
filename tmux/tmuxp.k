import regex
import .schema as schema

check_focus = lambda focus : str -> bool {
    focus == Undefined or (focus != Undefined and (focus == 'true' or focus == 'false'))
}

#check_focus2 = lambda focus : str -> bool {
#  focus == "true"
#}

get_first_cmd = lambda cmds : str | [str] -> str {
  if typeof(cmds) == "str":
    r = str(cmds)
  else:
    r = list(cmds)[0]
  r
}

is_focus = lambda name : str -> bool {
  regex.match(name, '^\*')
}

schema Session:
  session_name: str
  start_directory?: str
  environment?: schema.Env
  windows: [Window]
  shell_command_before?: str|[str]


schema Window:
  focus?: str
  layout?: str
  window_name: str
  environment?: schema.Env
  panes?: [Pane]
  start_directory?: str
  options?: {str:str}
  options_after?: {str:str}
  suppress_history?: bool
  window_index?: int
  shell_command_before?: str|[str]
  check:
    check_focus(focus)

schema Pane:
  focus?: str
  shell_command: str|[str]
#  check:
#    check_focus2(focus)

schema Env:
  [variable: str]: str


renders = lambda ts : [schema.Tmux] -> [Session] {
  [render(t) for t in ts]
}


render = lambda t : schema.Tmux -> Session {
  Session {
    session_name = t.name
    start_directory = t.workdir
    environment = t.env
    shell_command_before = t.before
    windows = [
      Window {
        if is_focus(win.name):
          focus = 'true'
          window_name = win.name[1:]
        else:
          window_name = win.name
        environment = win.env
        layout = win.layout
        start_directory = win.workdir
        options_after = win.options_after
        options = win.options
        suppress_history = win.suppress_history
        window_index = win.index
        shell_command_before = win.before
        panes = [
          Pane {
            if is_focus(get_first_cmd(pane)):
              focus = 'true'
              if typeof(pane) == "list":
                shell_command = [list(pane)[0][1:]] + list(pane)[1:]
              else:
                shell_command = str(pane)[1:]
            else:
              shell_command = pane
          } for pane in win.panes
        ]

      } for win in t.windows
    ]
  }
}
