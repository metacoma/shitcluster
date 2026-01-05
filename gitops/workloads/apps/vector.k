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
      customConfig = {
        data_dir = "/vector-data-dir"
        api = {
            enabled = True
            address = "127.0.0.1:8686"
            playground = False
        }
        sources = {
            kubernetes_logs = {
                $type = "kubernetes_logs"
            }
            host_metrics = {
                filesystem = {
                    devices = {
                        excludes = [
                            "binfmt_misc"
                        ]
                    }
                    filesystems = {
                        excludes = [
                            "binfmt_misc"
                        ]
                    }
                    mountpoints = {
                        excludes = [
                            "*/proc/sys/fs/binfmt_misc"
                        ]
                    }
                }
                $type = "host_metrics"
            }
            internal_metrics = {
                $type = "internal_metrics"
            }
        }
        sinks = {
            prom_exporter = {
                $type = "prometheus_exporter"
                inputs = [
                    "host_metrics"
                    "internal_metrics"
                ]
                address = "0.0.0.0:9090"
            }
            stdout = {
                $type = "console"
                inputs = [
                    "kubernetes_logs"
                ]
                encoding = {
                    codec = "json"
                }
            }
        }
      }
    }
    sync = {}
  )


]
