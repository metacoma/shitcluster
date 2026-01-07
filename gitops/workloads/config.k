_twitch_clipz_namespace = "twitch-clipz"

_neo4j_user = "ref+vault://kv/twitch_clipz#neo4j_user+"
_neo4j_password = "ref+vault://kv/twitch_clipz#neo4j_password+"

_ssh_tunnel_namespace = "network"


config = {
  k8s_domain = "k8s.mansion.shitcluster.io"

  storageClass = "longhorn"
  argocd = {
    namespace = "argocd"
  }

  nodeSelector = {
    "node-role.kubernetes.io/worker": ""
  }
  nodeAffinity = {
    requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms = [{
      matchExpressions = [{
        key = "node-role.kubernetes.io/worker"
        operator = "Exists"
      }]
    }]
  }

  rabbitmq = {
    release_name = "rabbitmq"
    namespace = "rabbitmq"
    port = 5672
    user = "ref+vault://kv/twitch_clipz#rabbitmq_user+"
    password = "ref+vault://kv/twitch_clipz#rabbitmq_password+"
  }
  twitch_clipz = {
    knative = {
      eventing = {
        broker = {
          telegram = {
            name = "telegram"
          }
        }
      }
      serving = {
        functions = {
          telegram_message = {
            name = "telegram-message"
            concurrency = 100
            timeout = 300
            image = {
              repo = "metacoma/telegram-message"
              tag = "sha256:300875fd266172d1f23a66cd5913d8b53910e2d55d40a3380f13394777c48051"
            }
          }
          twitch_download = {
            maxScale = "3"
            name = "twitch-download"
            concurrency = 1
            timeout = 600
            affinity = {
              podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution = [{
                labelSelector.matchExpressions = [{
                  key = "app"
                  operator = "In"
                  values = ["ssh-tunnel-nl0"]
                }]
                namespaces = [ _ssh_tunnel_namespace ]
                topologyKey = "kubernetes.io/hostname"
              }]
            }

            image = {
              repo = "metacoma/twitch-download-knative:latest"
              tag = "sha256:a5cc75ddffa7ce32b9e7abb499f3d15a43c91077f22c59832c7f15d9d1e03890"
            }
            resources = {
              requests.cpu = "500m"
              limits.cpu = "2"
            }
          }
        }
      }
    }
    namespace = _twitch_clipz_namespace
    configmap = "clipz-config"
    secret_name = "clipz-secret"

    telegram_bot = {
      app_name = "telegram-bot"
      token = "ref+vault://kv/twitch_clipz#telegram_bot_id"
      chats = {
        admin = "ref+vault://kv/twitch_clipz#telegram_admin_chat"
        monitoring = "ref+vault://kv/twitch_clipz#telegram_monitoring_chat"
      }
      container_image = "metacoma/clipz-telegram-bot:cloud-event8"
      rabbitmq_exchange = "telegram-events"
    }
    clipz = {
      app_name = "clipz"
      container_image = "metacoma/clipz:latest"
      rabbitmq_exchange = "telegram-events"
    }

    download = {
      app_name = "download"
      container_image = "metacoma/clipz-download:latest"
      rabbitmq_exchange = "telegram-video-send"
    }

    clipz_twitch = {
      app_name = "clipz-twitch"
      container_image = "metacoma/clipz-twitch:latest"
      rabbitmq_exchange = "twitch-events"
    }
    timer = {
      app_name = "timer"
      container_image = "metacoma/clipz-timer:latest"
      rabbitmq_exchange = "twitch-events"
    }

#    rabbitmq = {
#      user = "${rabbitmq.user}"
#      password = "${rabbitmq.password}"
#    }

    neo4j = {
      user = _neo4j_user
      password = _neo4j_password
    }
  }
  neo4j = {
    release_name = "neo4j"
    chart_version = "4.4.44"
    namespace = _twitch_clipz_namespace
    password = _neo4j_password
  }
  ssh_tunnel = {

    ssh_args = """-o Compression=no \
      -o UserKnownHostsFile=/dev/null \
      -o StrictHostKeyChecking=no \
      -o Ciphers=chacha20-poly1305@openssh.com  \
      -o MACs=umac-128-etm@openssh.com \
      -o KexAlgorithms=curve25519-sha256 \
      -o TCPKeepAlive=yes \
      -o ServerAliveInterval=15 \
      -o ServerAliveCountMax=3 \
      -o ExitOnForwardFailure=yes \
    """
    namespace = _ssh_tunnel_namespace
    container_image = "nicolaka/netshoot:latest"
    endpoints = [
      {
        host_network = {
          #type = "bridge"
          bridge = "br-public"
          ip = "172.25.220.2/16"
          gw = "172.25.0.1"
        }
        name = "nl0"
        country = "NL"
        ssh = {
          user = "ref+vault://kv/vpn_nl#ssh_user"
          host = "ref+vault://kv/vpn_nl#ssh_host"
          private_key = "ref+vault://kv/vpn_nl#ssh_private_key_base64"
        }
        local_addr = "10.50.0.2/24"
        remote_addr = "10.50.0.1/24"
        remote_tun = "tun5"
      }
    ]
  }

  monitoring = {
    namespace = "monitoring"
    alertmanager = {
      twitch_clipz_monitoring = {
        secret_name = "twitch-clipz-monitoring"
      }
      helm = {
        release_name = "alertmanager"
        chart_version = "1.30.0"
        app_version = "v0.30.0"
        repo = "https://prometheus-community.github.io/helm-charts"
        chart_name = "alertmanager"

      }
    }
    kube_state_metrics = {
      helm = {
        release_name = "kube-state-metrics"
        chart_version = "7.0.0"
        app_version = "2.17.0"
        repo = "https://prometheus-community.github.io/helm-charts"
        chart_name = "kube-state-metrics"

      }
    }
    node_exporter = {
      helm = {
        release_name = "node-exporter"
        chart_version = "4.49.2"
        app_version = "1.10.2"
        repo = "https://prometheus-community.github.io/helm-charts"
        chart_name = "prometheus-node-exporter"

      }
    }
    blackbox_exporter = {
      helm = {
        release_name = "blackbox-exporter"
        chart_version = "11.6.1"
        app_version = "v0.28.0"
        repo = "https://prometheus-community.github.io/helm-charts"
        chart_name = "prometheus-blackbox-exporter"

      }
    }
    vm_operator = {
      helm = {
        release_name = "vm-operator"
        chart_version = "0.57.1"
        app_version = "v0.66.1"
        repo = "https://victoriametrics.github.io/helm-charts/"
        chart_name = "victoria-metrics-operator"

      }
    }
    vm_single = {
      helm = {
        release_name = "vm-single"
        chart_version = "0.27.0"
        app_version = "v1.132.0"
        repo = "https://victoriametrics.github.io/helm-charts/"
        chart_name = "victoria-metrics-single"

      }
    }
    vm_agent = {
      helm = {
        release_name = "vm-agent"
        chart_version = "0.28.0"
        app_version = "v1.132.0"
        repo = "https://victoriametrics.github.io/helm-charts/"
        chart_name = "victoria-metrics-agent"

      }
    }
    grafana = {
      helm = {
        repo = "https://grafana.github.io/helm-charts"
        release_name = "grafana"
        chart_version = "10.4.0"
        app_version = "12.0.4"
        chart_name = "grafana"
      }
    }
  }
  observability = {
    namespace = "observability"
    loki = {
      helm = {
        repo = "https://grafana.github.io/helm-charts"
        release_name = "loki"
        chart_version = "6.49.0"
        app_version = "3.6.3"
        chart_name = "loki"
      }
    }
    tempo = {
      helm = {
        repo = "https://grafana.github.io/helm-charts"
        release_name = "tempo"
        chart_version = "1.24.1"
        app_version = "2.9.0"
        chart_name = "tempo"
      }
    }
    otlp = {
      helm = {
        repo = "https://open-telemetry.github.io/opentelemetry-helm-charts"
        release_name = "otlp"
        chart_version = "0.142.0"
        app_version = "0.142.0"
        chart_name = "opentelemetry-collector"
      }
    }
  }
  istio = {
    namespace = "istio-system"
    gateway_lb = "172.25.1.6"
    helm = {
      istio_base = {
        chart_name = "base"
        repo = "https://istio-release.storage.googleapis.com/charts"
        chart_version = "1.28.1"
        app_version = "1.28.1"
        release_name = "istio-base"
      }
      istiod = {
        chart_name = "istiod"
        repo = "https://istio-release.storage.googleapis.com/charts"
        app_version = "1.28.1"
        chart_version = "1.28.1"
        release_name = "istiod"
      }
      gateway = {
        chart_name = "gateway"
        repo = "https://istio-release.storage.googleapis.com/charts"
        app_version = "1.28.1"
        chart_version = "1.28.1"
        release_name = "istio-ingressgateway"
      }
    }
  }
  knative = {
    domain = "kn.public.mansion.shitcluster.io"
    operator = {
      namespace = "knative-operator"
      helm = {
        chart = "knative-operator"
        repo = "https://knative.github.io/operator"
        release_name = "knative-operator"
        version = "1.20.0"
        app_version = "v1.20.0"
      }

    }
    eventing = {
      namespace = "knative-eventing"
      version = "1.20.0"
    }
    serving = {
      namespace = "knative-serving"
      version = "1.20.0"
    }
  }
  vector = {
    namespace = "vector"
    vector = {
      helm = {
        chart_name = "vector"
        repo = "https://helm.vector.dev"
        release_name = "vector"
        chart_version = "0.49.0"
        app_version = "0.52.0-distroless-libc"
      }
    }
  }
}
