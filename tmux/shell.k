import base64

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

yaml_file = lambda file : str, yaml_data : any -> str {
  "echo ${base64.encode(yaml_data)} | base64 -d | yq | tee ${file}"
}

text_file = lambda file : str, text : str -> str {
  "echo ${base64.encode(text)} | base64 -d | tee ${file}"
}
