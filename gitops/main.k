import k8s.api.core.v1 as k8core
import manifests

resources = [
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
