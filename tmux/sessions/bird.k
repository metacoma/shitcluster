import manifests
import tmux.schema as schema
import tmux.shell
import tmux.sessions.ssh_tunnels

sessions = [
  schema.Tmux {
  name = "bird"
  workdir = "/etc/bird"
  env = {
    EDITOR = "nvim"
  }
  before = [
    shell.alias("bgp", "ip ro | wc -l")
    shell.alias("pod_ip", ssh_tunnels.pod_ip_cmd("nl0"))
  ] + shell.service_cmd_alias("bird")

  windows = [
     schema.Window {
        name: "*bird"
        panes = [
          ["*sudo $EDITOR /etc/bird/bird.conf"]
          ["bgp"]
        ]
    }]
  }
]
