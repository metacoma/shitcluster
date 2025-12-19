import k8s.api.core.v1 as k8s
import k8s.api.apps.v1 as v1
import config as cfg

_config = cfg.config
monitoring = _config.monitoring

manifests = [
  k8s.Namespace {
    metadata.name = monitoring.namespace
  }
]
