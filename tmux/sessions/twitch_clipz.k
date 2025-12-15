import manifests
import tmux.schema as schema
import tmux.shell
import gitops.workloads.config as config

_config = config.config
cfg = _config.twitch_clipz
rabbitmq = _config.rabbitmq

mgmt_domain = "mgmt.mansion.shitcluster.io"

sessions = [
  schema.Tmux {
  name = "twitch-clipz"
  workdir = "~"

  windows = [
    schema.Window {
        name = "*dashboard"
        layout = "92b0,190x44,0,0[190x13,0,0,262,190x8,0,14,263,190x21,0,23,264]"
        panes = [
          ["kubectl -n ${cfg.namespace} get pods -o wide -w"]
          ["kubectl -n ${rabbitmq.namespace} get pods -o wide -w"]
          ["kubectl -n ${cfg.namespace} get events -w -o wide"]
        ]
    }
    schema.Window {
      name = "download"
      env.SSH_AUTH_SOCK = ""
      panes = [
        [
          "WORKER_NODE=$(kubectl get pod -n ${cfg.namespace} -l app=download -o jsonpath='{.items[0].spec.nodeName}')"
          "ssh -t $WORKER_NODE.${mgmt_domain} htop"

        ]
        [
          "kubectl -n ${cfg.namespace} logs -f deployment/download"
        ]
      ]
    }
    schema.Window {
      name = "logs"
      panes = [
        [
          "kubectl -n ${cfg.namespace} logs -f deployment/clipz-twitch"
        ]
          "kubectl -n ${cfg.namespace} logs -f deployment/telegram-bot"
      ]
    }
  ]

  }
]
