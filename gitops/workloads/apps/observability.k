import k8s.api.core.v1 as k8s
import k8s.api.apps.v1 as v1
import config as cfg
import ..argoproj.v1alpha1 as argoproj
import yaml


_config = cfg.config
observability = _config.observability

observability_app = lambda helm : any, values : any, sync : any -> argoproj.Application {
  argoproj.Application {
    metadata = {
        name = helm.release_name
        namespace = _config.argocd.namespace
    }
    spec = {
        destination = {
            namespace = observability.namespace
            name = "in-cluster"
        }
        project = "default"
        source = {
            chart = helm.chart_name
            repoURL = helm.repo
            targetRevision = helm.chart_version
            helm = {
              values = yaml.encode(values)
            }
        }
        syncPolicy = {
            automated = {
                selfHeal = True
            }
        } | sync

    }
  }
}

manifests = [
  k8s.Namespace {
    metadata.name = observability.namespace
  }
  observability_app(
    observability.loki.helm, values = {
      nodeSelector = _config.nodeSelector
      deploymentMode = "SingleBinary"
      loki = {
        auth_enabled = False
        commonConfig.replication_factor = 1
        storage = "filesystem"
      }
    }
    sync = {}
  )
]
