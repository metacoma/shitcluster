kubernetes_ns = lambda ns : str -> any {
  {
    ns = ns
    exec = "kubectl -n ${ns} exec"
    get = "kubectl -n ${ns} get"
    log = "kubectl -n ${ns} logs"
  }
}

systemctl = lambda name : str, action : str -> str {
  "sudo systemctl ${action} ${name}"
}

service = systemctl

service_cmd_alias = lambda name : str -> [str] {
  [alias(a, service(name, a)) for a in ["start", "restart", "stop", "status"]]
}

alias = lambda name : str, cmd : str -> str {
  'alias ${name}="${cmd}"'
}
