import k8s.api.core.v1 as k8core
import argoproj.v1alpha1 as argoproj
import yaml
import manifests



resources = [
    argoproj.Application {
        metadata = {
            name = "ingress-nginx"
            namespace = "argocd"
        }
        spec = {
            destination = {
                namespace = "ingress-nginx"
                server = "https://kubernetes.default.svc"
            }
            project = "default"
            source = {
                chart = "ingress-nginx"
                repoURL = "https://kubernetes.github.io/ingress-nginx"
                targetRevision = "4.14.0"
                helm = {
                    values = yaml.encode({})
                    releaseName = "ingress-nginx"
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


    k8core.Namespace {
                    metadata.name = "test-namespace"
    }
    k8core.Namespace {
                    metadata.name = "test-namespace2"
    }
]

manifests.yaml_stream([
    resources
])
