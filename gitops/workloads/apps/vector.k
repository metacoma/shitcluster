import k8s.api.core.v1 as k8s
import k8s.api.apps.v1 as v1
import config as cfg
import ..argoproj.v1alpha1 as argoproj
import yaml

_config = cfg.config
vector = _config.vector


vector_app = lambda helm : any, values : any, sync : any -> argoproj.Application {
  argoproj.Application {
    metadata = {
        name = helm.release_name
        namespace = _config.argocd.namespace
    }
    spec = {
        destination = {
            namespace = vector.namespace
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
    metadata.name = vector.namespace
  }

  vector_app(
    vector.vector.helm | { release_name = "aggregator" }
    {
      role = "Aggregator"
      nodeSelector = _config.nodeSelector
    }
    sync = {}
  )


  vector_app(
    vector.vector.helm, {
      role = "Agent"
    }
    sync = {}
  )


]
