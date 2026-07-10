import k8s.api.core.v1 as k8s
import config as cfg
import ..argoproj.v1alpha1 as argoproj
import yaml

_config = cfg.config
netbird = _config.netbird

manifests = [
  k8s.Namespace {
    metadata.name = netbird.namespace
  }
  argoproj.Application {
    metadata = {
      name = netbird.helm.release_name
      namespace = "argocd"
    }
    spec = {
      destination = {
        namespace = netbird.namespace
        name = "in-cluster"
      }
      project = "default"
      source = {
        chart = netbird.helm.chart
        repoURL = netbird.helm.repo
        targetRevision = netbird.helm.version
        helm = {
          values = yaml.encode({
            nodeSelector = _config.nodeSelector.worker

            management = {
              service = {
                type = "LoadBalancer"
                loadBalancerIP = netbird.management.loadBalancerIP
              }
              serviceGrpc = {
                type = "LoadBalancer"
                loadBalancerIP = netbird.management.grpcLoadBalancerIP
              }
              podCommand.args = [
                "--port=80"
                "--log-file=console"
                "--log-level=info"
                "--disable-anonymous-metrics=true"
                "--idp-manager-config=disabled"
              ]
              env = {
                CORS_ALLOWED_ORIGINS = "*"
              }
            }

            signal = {
              service = {
                type = "LoadBalancer"
                loadBalancerIP = netbird.signal.loadBalancerIP
              }
            }

            relay = {
              service = {
                type = "LoadBalancer"
                loadBalancerIP = netbird.relay.loadBalancerIP
              }
            }

            dashboard = {
              enabled = True
              service = {
                type = "LoadBalancer"
                loadBalancerIP = netbird.dashboard.loadBalancerIP
              }
            }
          })
          releaseName = netbird.helm.release_name
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
