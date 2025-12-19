import k8s.api.core.v1 as k8s
import k8s.api.apps.v1 as v1
import config as cfg
import ..argoproj.v1alpha1 as argoproj
import yaml


_config = cfg.config
knative = _config.knative

operator = knative.operator
eventing = knative.eventing
serving = knative.serving

manifests = [

  k8s.Namespace {
    metadata.name = operator.namespace
  }

  argoproj.Application {
    metadata = {
        name = knative.operator.helm.release_name
        namespace = _config.argocd.namespace
    }
    spec = {
        destination = {
            namespace = operator.namespace
            name = "in-cluster"
        }
        project = "default"
        source = {
            chart = operator.helm.chart
            repoURL = operator.helm.repo
            targetRevision = operator.helm.version
            helm = {
                values = yaml.encode({
                  knative_operator = {
                    knative_operator.affinity.nodeAffinity = _config.nodeAffinity
                    operator_webhook.affinity.nodeAffinity = _config.nodeAffinity
                  }
                })
                releaseName = knative.operator.helm.release_name
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
