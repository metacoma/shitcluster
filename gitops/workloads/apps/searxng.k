import k8s.api.core.v1 as k8s
import config as cfg
import ..argoproj.v1alpha1 as argoproj
import yaml

_config = cfg.config
searxng = _config.searxng

manifests = [
    k8s.Namespace {
        metadata.name = searxng.namespace
    }
    argoproj.Application {
        metadata = {
            name = searxng.helm.release_name
            namespace = "argocd"
        }
        spec = {
            destination = {
                namespace = searxng.namespace
                name = "in-cluster"
            }
            project = "default"
            source = {
                chart = searxng.helm.chart
                repoURL = searxng.helm.repo
                targetRevision = searxng.helm.version
                helm = {
                    values = yaml.encode({
                        secretKey = searxng.secret_key
                        podTemplate.merge.spec.nodeSelector = _config.nodeSelector.worker
                    })
                    releaseName = searxng.helm.release_name
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
]
