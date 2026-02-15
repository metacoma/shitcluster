import k8s.api.core.v1 as k8s
import k8s.api.apps.v1 as v1
import config as cfg
import ..argoproj.v1alpha1 as argoproj
import yaml

_config = cfg.config
nats = _config.nats

manifests = [
  k8s.Namespace {
    metadata.name = nats.namespace
  }
  argoproj.Application {
    metadata = {
        name = nats.helm.release_name
        namespace = "argocd"
    }
    spec = {
        destination = {
            namespace = nats.namespace
            name = "in-cluster"
        }
        project = "default"
        source = {
            chart = nats.helm.chart
            repoURL = nats.helm.repo
            targetRevision = nats.helm.version
            helm = {
                values = yaml.encode({
                })
                releaseName = nats.helm.release_name
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
