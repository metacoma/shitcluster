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
      customConfig = {
        data_dir = "/vector-data-dir"
        api = {
            enabled = True
            address = "127.0.0.1:8686"
            playground = False
        }
        sources = {
            datadog_agent = {
                address = "0.0.0.0:8282"
                $type = "datadog_agent"
            }
            fluent = {
                address = "0.0.0.0:24224"
                $type = "fluent"
            }
            internal_metrics = {
                $type = "internal_metrics"
            }
            logstash = {
                address = "0.0.0.0:5044"
                $type = "logstash"
            }
            splunk_hec = {
                address = "0.0.0.0:8080"
                $type = "splunk_hec"
            }
            statsd = {
                address = "0.0.0.0:8125"
                mode = "tcp"
                $type = "statsd"
            }
            syslog = {
                address = "0.0.0.0:9000"
                mode = "tcp"
                $type = "syslog"
            }
            vector = {
                address = "0.0.0.0:6000"
                $type = "vector"
                version = "2"
            }
        }
        transforms = {
            container_logs = {
                $type = "remap"
                inputs = [
                    "vector"
                ]
                source = r""".namespace = .kubernetes.pod_namespace
.pod_name = .kubernetes.pod_name
.container_name = .kubernetes.container_name
.hostname = .kubernetes.node_labels."kubernetes.io/hostname"
del(.file)
del(.kubernetes)
del(.source_type)
del(.stream)
    """
          }

        traceback_lines = {
            $type = "filter"
            inputs = [
                "vector"
            ]
            condition = r"""msg = to_string(.message)
strict = starts_with(msg, "Traceback (most recent call last):")

has_tb = contains(msg, "Traceback (most recent call last):")
has_file_line = match(msg, r'File ".*", line \d+')
prefixed = has_tb && has_file_line

strict || prefixed
"""
        }
        alertmanager_payload = {
            $type = "remap"
            inputs = [
                "traceback_lines"
            ]
            source = r"""alert = {
  "labels": {
    "alertname": "PythonTracebackDetected",
    "severity": "warning"
  },
  "annotations": {
    "summary": "Python traceback detected",
    "description": to_string(.message) ?? ""
  },
  "startsAt": format_timestamp!(now(), format: "%+")
}

.body = encode_json([alert])
"""
          }

        }
        sinks = {
            to_loki = {
              $type = "loki"
              inputs = [ "container_logs" ]
              endpoint = "http://loki.observability:3100"
              encoding.codec = "text"
              labels = {
                namespace = '{{ "{{" }} namespace {{ "}}" }}'
                pod       = '{{ "{{" }} pod_name {{ "}}" }}'
                container = '{{ "{{" }} container_name {{ "}}" }}'
                node = '{{ "{{" }} hostname {{ "}}" }}'
              }
              remove_label_fields = True
            }
            to_alertmanager = {
                $type = "http"
                inputs = [
                    "alertmanager_payload"
                ]
                method = "post"
                uri = "http://alertmanager.monitoring.svc:9093/api/v2/alerts"
                headers = {
                    "Content-Type" = "application/json"
                }
                encoding = {
                    codec = "text"
                    text = {
                        field = "body"
                    }
                }
                batch = {
                    max_events = 1
                    timeout_secs = 1
                }
            }
            prom_exporter = {
                $type = "prometheus_exporter"
                inputs = [
                    "internal_metrics"
                ]
                address = "0.0.0.0:9090"
            }
            stdout = {
                $type = "console"
                inputs = [
                  "alertmanager_payload"
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
            logs_to_aggregator = {
                $type = "vector"
                inputs = [ "kubernetes_logs" ]
                address = "aggregator-vector:6000"
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
