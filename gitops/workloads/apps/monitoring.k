import k8s.api.core.v1 as k8s
import k8s.api.apps.v1 as v1
import config as cfg
import ..argoproj.v1alpha1 as argoproj
import yaml
import victoria_metrics_operator.v1beta1.operator_victoriametrics_com_v1beta1_vm_service_scrape as vm_service_scrape

_config = cfg.config
monitoring = _config.monitoring

monitoring_app = lambda helm : any, values : any, sync : any -> argoproj.Application {
#monitoring_app = lambda helm : any, values : any, sync : any -> any {
  argoproj.Application {
    metadata = {
        name = helm.release_name
        namespace = _config.argocd.namespace
    }
    spec = {
        destination = {
            namespace = monitoring.namespace
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
    metadata.name = monitoring.namespace
  }
  monitoring_app(
    monitoring.kube_state_metrics.helm, values = {
      nodeSelector = _config.nodeSelector
      resources.requests = {
        cpu = "10m"
        memory = "32Mi"
      }
      resources.limits = {
        cpu = "10m"
        memory = "64Mi"
      }
    }
    sync = {}
  )

  monitoring_app(
    monitoring.node_exporter.helm, values = {
    }, sync = {}

  )
  monitoring_app(
    monitoring.blackbox_exporter.helm, values = {
      nodeSelector = _config.nodeSelector
    },
    sync = {}
  )

  monitoring_app(
    monitoring.vm_operator.helm, values = {
      nodeSelector = _config.nodeSelector
    }
    sync = {
      syncOptions = [
        "RespectIgnoreDifferences=true"
      ]
    }
  ) | {
    spec.ignoreDifferences = [
      {
        group = ""
        kind = "Secret"
        name = "${monitoring.vm_operator.release_name}-validation"
        namespace = monitoring.namespace
        jsonPointers = ["/data"]
      }
      {
        group = "admissionregistration.k8s.io"
        kind = "ValidatingWebhookConfiguration"
        name = "${monitoring.vm_operator.release_name}-validation"
        namespace = monitoring.namespace
        jqPathExpressions = ['.webhooks[]?.clientConfig.caBundle']
      }

    ]
  }

  monitoring_app(
    monitoring.vm_agent.helm, values = {
      nodeSelector = _config.nodeSelector
      remoteWrite = [{
        url = "http://vm-single-victoria-metrics-single-server.monitoring:8428/api/v1/write"
      }]
    }, sync = {}
  )
  [
  vm_service_scrape.VMServiceScrape {
    metadata = {
      name = "${service_name}-exporter"
      namespace = _config.monitoring.namespace
    }
    spec = {
      selector.matchLabels = {
        "app.kubernetes.io/name" = service_name
      }
      namespaceSelector.matchNames = [_config.monitoring.namespace]
      endpoints = [{
        port = "metrics"
        interval = "30s"
      }]

    }
  }
  for service_name in ["prometheus-node-exporter", "kube-state-metrics", "prometheus-blackbox-exporter" ]
  ]

  monitoring_app(
    monitoring.grafana.helm, values = {
      nodeSelector = _config.nodeSelector

      adminUser = "ref+vault://kv/grafana#adminUser"
      adminPassword = "ref+vault://kv/grafana#adminPassword"
      image.tag = monitoring.grafana.helm.app_version
      service = {
        type = "LoadBalancer"
        loadBalancerIP = "172.25.1.5"
      }
      persistence = {
        enabled = True
      }
      datasources = {
        "datasources.yaml" = {
          apiVersion = 1
          datasources = [{
            name = "VictoriaMetrics"
            type = "prometheus"
            uid = "vm"
            access = "proxy"
            url = "http://${_config.monitoring.vm_single.helm.release_name}-victoria-metrics-single-server.${_config.monitoring.namespace}.svc:8428"
            isDefault = True
            editable = True
          }]
        }
        "datasources-loki.yaml" = {
          apiVersion = 1
          datasources = [{
            name = "loki"
            type = "loki"
            uid = "loki"
            access = "proxy"
            url = "http://${_config.observability.loki.helm.release_name}.${_config.observability.namespace}:3100"
            editable = False
          }]
        }
        "datasources-tempo.yaml" = {
          apiVersion = 1
          datasources = [{
            name = "tempo"
            type = "tempo"
            uid = "tempo"
            access = "proxy"
            url = "http://${_config.observability.tempo.helm.release_name}.${_config.observability.namespace}:3200"
            editable = False
            jsonData = {
              httpMethod = "GET"
              serviceMap.datasourceUid = "vm"
            }
          }]
        }
      }
    },
    sync = {}
  )

]
