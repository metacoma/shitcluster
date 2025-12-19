import k8s.api.core.v1 as k8s
import k8s.api.apps.v1 as v1
import config as cfg
import ..argoproj.v1alpha1 as argoproj
import yaml

_config = cfg.config
monitoring = _config.monitoring
kube_state_metrics = monitoring.kube_state_metrics
node_exporter = monitoring.node_exporter

monitoring_app = lambda helm : any, values : any, syncOptions : any -> argoproj.Application {
  argoproj.Application {
    metadata = {
        name = helm.release_name
        namespace = _config.argocd.namespace
    }
    spec = {
        destination = {
            namespace = monitoring.namespace
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
            } | syncOptions
        }
    }
  }
}

manifests = [
  k8s.Namespace {
    metadata.name = monitoring.namespace
  }
  monitoring_app(
    monitoring.kube_state_metrics.helm, values = {
      nodeSelector = _config.nodeSelector
      resources.requests = {
        cpu = "10m"
        memory = "32Mi"
      }
      resources.limits = {
        cpu = "10m"
        memory = "64Mi"
      }
    }
    syncOptions = {}
  )

  monitoring_app(
    monitoring.node_exporter.helm, values = {
    }, syncOptions = {}

  )
  monitoring_app(
    monitoring.blackbox_exporter.helm, values = {
      nodeSelector = _config.nodeSelector
    },
    syncOptions = {}
  )

  monitoring_app(
    monitoring.vm_operator.helm, values = {
      nodeSelector = _config.nodeSelector
    }
    syncOptions = {
      RespectIgnoreDifferences = True
    }
  )
]
