import manifests
import tmux.schema as schema
import tmux.shell as shell
import gitops.workloads.config as config

_config = config.config
monitoring = _config.monitoring

k = shell.kubernetes_ns(monitoring.namespace)

sessions = [
  schema.Tmux {
  name = "alertmanager"
  workdir = "/home/ubuntu/shitcluster/shitcluster"

  windows = [
     schema.Window {
        name: "*alertmanager"
        panes = [
          ["*${k.exec} -ti statefulset/alertmanager -- /bin/sh"]
        ]
      }
    ]
  }
]
