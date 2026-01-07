import manifests
import tmux.schema as schema
import tmux.shell

argocd_ns = "argocd"

sessions = [
  schema.Tmux {
  name = "argocd"
  workdir = "/home/ubuntu/shitcluster/shitcluster"
  env = {
    EDITOR = "nvim"
  }
  before = [
  ]

  windows = [
     schema.Window {
        name: "*argocd"
        panes = [
          ["*kubectl -n ${argocd_ns} get pods"]
          ["make argocd_password"]
        ]
      }
     schema.Window {
        name: "kcl-plugin"
        panes = [
          ["kubectl -n ${argocd_ns} logs --tail=10 -f deployment/argocd-repo-server -c my-plugin"]
          ["kubectl -n ${argocd_ns} exec -ti deployment/argocd-repo-server -c my-plugin -- /bin/bash"]
        ]
      }
    ]
  }
]
