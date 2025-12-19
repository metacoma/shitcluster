import k8s.api.core.v1 as k8s
import k8s.api.apps.v1 as v1
import config as cfg
import ..argoproj.v1alpha1 as argoproj
import yaml

_config = cfg.config
monitoring = _config.monitoring
kube_state_metrics = monitoring.kube_state_metrics

manifests = [
  k8s.Namespace {
    metadata.name = monitoring.namespace
  }

  argoproj.Application {
    metadata = {
        name = kube_state_metrics.helm.release_name
        namespace = _config.argocd.namespace
    }
    spec = {
        destination = {
            namespace = monitoring.namespace
            name = "in-cluster"
        }
        project = "default"
        source = {
            chart = kube_state_metrics.helm.chart_name
            repoURL = kube_state_metrics.helm.repo
            targetRevision = kube_state_metrics.helm.chart_version
            helm = {
              values = yaml.encode({
                nodeSelector = _config.nodeSelector
                resources.requests = {
                  cpu = "10m"
                  memory = "32Mi"
                }
                resources.limits = {
                  cpu = "10m"
                  memory = "64Mi"
                }
              })
            }
        }
        syncPolicy = {
            automated = {
                selfHeal = True
            }
        }
    }
  }

]
