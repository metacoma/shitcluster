import k8s.api.core.v1 as k8s
import yaml
import file
import manifests

infra_ns = "infra"

resources = [
  k8s.Namespace {
    metadata.name = infra_ns
  }

  k8s.Secret {
    metadata = {
      name = "sops"
      namespace = infra_ns
    }
    stringData = {
      public_key = "ref+vault://kv/sops#public_key"
      age_key = "ref+vault://kv/sops#age_secret_key"
    }
  }
]

manifests.yaml_stream([
    resources
])
