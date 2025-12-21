import k8s.api.core.v1 as k8s
import k8s.api.apps.v1 as v1
import config as cfg
import ..argoproj.v1alpha1 as argoproj
import yaml
import knative_operator.v1beta1 as kn


_config = cfg.config
knative = _config.knative

operator = knative.operator
eventing = knative.eventing
serving = knative.serving

_observability = _config.observability

manifests = [

  k8s.Namespace {
    metadata.name = operator.namespace
  }

  k8s.Namespace {
    metadata = {
      name = serving.namespace
      labels = {
        "istio-injection" = "enabled"
      }
    }
  }

  k8s.Namespace {
    metadata.name = eventing.namespace
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
  kn.KnativeServing {
      metadata.name = "knative-serving"
      metadata.namespace = _config.knative.serving.namespace
      metadata.annotations = {
          "argocd.argoproj.io/sync-options" = "SkipDryRunOnMissingResource=true"
      }
      spec.version = _config.knative.serving.version
      spec.config = {
          observability = {
              "metrics.backend-destination" = "prometheus"
             "metrics.request-metrics-backend-destination" = "prometheus"
          }
          domain = {
            "${knative.domain}" = ""
          }
          tracing = {
              backend = "zipkin"
              "zipkin-endpoint" = "http://${_observability.tempo.helm.release_name}.${_observability.namespace}:9411/api/v2/spans"
              "sample-rate" = "1"
              debug = "true"
          }
          #deployment = {
          #    "registries-skipping-tag-resolving" = "zot-int.zot.svc.cluster.local:5000,zot-int.zot:5000,127.0.0.1:30001"
          #}
          "external-gateways" = {
            name = "knative-ingress-gateway"
            namespace = serving.namespace
            service = "istio-ingressgateway.istio-system.svc.${_config.k8s_domain}"
          }
          "local-gateways" = {
            name = "knative-local-gateway"
            namespace = serving.namespace
            service = "knative-local-gateway.istio-system.svc.${_config.k8s_domain}"
          }

      }
      spec.workloads = [
        {
          name = workload
          nodeSelector = _config.nodeSelector
        }
      for workload in ["activator" "autoscaler" "autoscaler-hpa" "controller" "net-istio-controller" "net-istio-webhook" "webhook"]
      ]
  }


  kn.KnativeEventing {
      metadata.name = "knative-eventing"
      metadata.namespace = _config.knative.eventing.namespace
      metadata.annotations = {
          "argocd.argoproj.io/sync-options" = "SkipDryRunOnMissingResource=true"
      }
      spec.version = _config.knative.eventing.version
      spec.config.tracing = {
          backend = "zipkin"
          "zipkin-endpoint" = "http://${_observability.tempo.helm.release_name}.${_observability.namespace}:9411/api/v2/spans"
          "sample-rate" = "1"
          debug = "true"
      }
      spec.config.observability = {
          "metrics.backend-destination" = "prometheus"
          # "metrics.opencensus-address" = config.monitoring.opencensus_endpoint(config.monitoring.tempo.release_name, config.monitoring.namespace)
      }
      spec.workloads = [
        {
          name = workload
          nodeSelector = _config.nodeSelector
        }
      for workload in ["eventing-controller" "eventing-webhook" "imc-controller" "imc-dispatcher" "job-sink" "mt-broker-controller" "mt-broker-filter" "mt-broker-ingress" "pingsource-mt-adapter"]
      ]
  }

]
