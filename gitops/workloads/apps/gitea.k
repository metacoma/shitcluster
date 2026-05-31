import ..argoproj.v1alpha1 as argoproj
import yaml
import config as cfg

_config = cfg.config
_gitea = _config.gitea

application = argoproj.Application {
  metadata = {
      name = _gitea.helm.release_name
      namespace = "argocd"
  }
  spec = {
      destination = {
          namespace = _gitea.namespace
          name = "in-cluster"
      }
      project = "default"
      source = {
          chart = _gitea.helm.chart
          repoURL = _gitea.helm.repo
          targetRevision = _gitea.helm.version
          helm = {
              values = yaml.encode({
                persistence = {
                  enabled = True
                  size = "10Gi"
                }
                postgresql = {
                  enabled = False
                }
                gitea = {
                  config = {
                    "server" = {
                      "APP_DATA_PATH" = "/var/log/gitea"
                    }
                    "repository" = {
                      "DEFAULT_BRANCH" = "main"
                    }
                    "service" = {
                      "DISABLE_REGISTRATION" = False
                    }
                  }
                }
                nodeSelector = _config.nodeSelector.worker
              })
              releaseName = _gitea.helm.release_name
          }
      }
      syncPolicy = {
          automated = {
              selfHeal = True
          }
          syncOptions = [
              "CreateNamespace=true"
          ]
      }
  }
}
