import k8s.api.core.v1 as k8s
import k8s.api.apps.v1 as v1
import config as cfg
import knative.v1.eventing_knative_dev_v1_broker as knative_broker
import knative.v1.eventing_knative_dev_v1_trigger as knative_trigger

import knative.v1.serving_knative_dev_v1_service as knative_service


_config = cfg.config
_twitch_clipz = _config.twitch_clipz
_rabbitmq = _config.rabbitmq
_neo4j = _config.neo4j

_rabbitmq_url = "amqp://${_rabbitmq.user}:${_rabbitmq.password}@${_rabbitmq.release_name}.${_rabbitmq.namespace }:${_rabbitmq.port}/"

telegram_broker = lambda name : str, broker : any -> knative_broker.Broker {
  knative_broker.Broker {
    metadata = {
      name = broker.name
      namespace = _twitch_clipz.namespace
    }
  }
}

makeClipzDeployment = lambda component : any -> v1.Deployment {
  v1.Deployment {
    metadata = {
      name = component.name
      namespace = _twitch_clipz.namespace
      labels = {
        app = component.name
      }
    }
    spec = {
      selector.matchLabels = {app = component.name }
      template = {
        metadata.labels = {app = component.name }
        spec = {
          nodeSelector = _config.nodeSelector
          containers = [{
            name = component.name
            image = component.image
            imagePullPolicy = "IfNotPresent"
            if component.resources:
              resources = component.resources
            env = [{
              name = "RABBITMQ_EXCHANGE_NAME"
              value = component.rabbitmq_exchange
            }]
            envFrom = [
              { configMapRef.name = _twitch_clipz.configmap }
              { secretRef.name = _twitch_clipz.secret_name }
            ]
          }]
        }
      }
    }
  }

}

manifests = [
  k8s.Namespace {
    metadata = {
      name = _twitch_clipz.namespace
      labels = {
        "istio-injection" = "enabled"
      }
    }
  }
  k8s.ConfigMap {
    metadata = {
      name = _twitch_clipz.configmap
      namespace = _twitch_clipz.namespace
    }
    data = {
      NEO4J_URL = "${_neo4j.release_name}.${_neo4j.namespace}:7687"
    }
  }
  k8s.Secret {
    metadata = {
      namespace = _twitch_clipz.namespace
      name = _twitch_clipz.secret_name
    }
    stringData = {
      TELEGRAM_BOT_TOKEN = _twitch_clipz.telegram_bot.token
      TELEGRAM_ADMIN_CHAT_ID = _twitch_clipz.telegram_bot.chats.admin
      RABBITMQ_URL = _rabbitmq_url
      NEO4J_USER = _twitch_clipz.neo4j.user
      NEO4J_PASSWORD = _twitch_clipz.neo4j.password
    }
  }
  makeClipzDeployment({
    name = _twitch_clipz.telegram_bot.app_name
    image = _twitch_clipz.telegram_bot.container_image
    rabbitmq_exchange = _twitch_clipz.telegram_bot.rabbitmq_exchange
  })
  makeClipzDeployment({
    name = _twitch_clipz.clipz.app_name
    image = _twitch_clipz.clipz.container_image
    rabbitmq_exchange = _twitch_clipz.clipz.rabbitmq_exchange
  })
  makeClipzDeployment({
    name = _twitch_clipz.download.app_name
    image = _twitch_clipz.download.container_image
    rabbitmq_exchange = _twitch_clipz.download.rabbitmq_exchange
    resources = {
      requests.cpu = "500m"
      limits.cpu = "2"
    }
  })
  makeClipzDeployment({
    name = _twitch_clipz.clipz_twitch.app_name
    image = _twitch_clipz.clipz_twitch.container_image
    rabbitmq_exchange = _twitch_clipz.clipz_twitch.rabbitmq_exchange
  })
  makeClipzDeployment({
    name = _twitch_clipz.timer.app_name
    image = _twitch_clipz.timer.container_image
    rabbitmq_exchange = _twitch_clipz.timer.rabbitmq_exchange
  })
  # knative
  [
    [
      telegram_broker(broker.name, broker)
    ]  for broker_name, broker in _config.twitch_clipz.knative.eventing.broker
  ]

  knative_trigger.Trigger {
    metadata = {
      name = "telegram-message"
      namespace = _twitch_clipz.namespace
    }
    spec = {
      broker = _twitch_clipz.knative.eventing.broker.telegram.name
      filters = [{
        prefix.type = "telegram.message"
      }]
      subscriber.ref = {
        apiVersion = "serving.knative.dev/v1"
        kind = "Service"
        name = _twitch_clipz.knative.serving.functions.telegram_message.name
      }
    }
  }

  knative_trigger.Trigger {
    metadata = {
      name = "twitch-clip"
      namespace = _twitch_clipz.namespace
    }
    spec = {
      broker = _twitch_clipz.knative.eventing.broker.telegram.name
      "filter" = {
        attributes.type = "twitch.clip"
      }
      subscriber.ref = {
        apiVersion = "serving.knative.dev/v1"
        kind = "Service"
        name = _twitch_clipz.knative.serving.functions.twitch_download.name
      }
    }
  }

  [
    [
      knative_service.Service {
        metadata = {
          name = func.name
          namespace = _twitch_clipz.namespace
        }
        spec.template = {
          metadata.annotations = {
            "autoscaling.knative.dev/max-scale" = func.maxScale
          }
          spec = {
            enableServiceLinks = False
            nodeSelector = _config.nodeSelector
            timeoutSeconds = func.timeout
            containerConcurrency = func.concurrency
            affinity = func.affinity
            containers = [{
              env = [
                { name = "ADDRESS", value = "0.0.0.0" }
              ]
              image = "${func.image.repo}@${func.image.tag}"
              envFrom = [
                { configMapRef.name = _twitch_clipz.configmap }
                { secretRef.name = _twitch_clipz.secret_name }
              ]
              name = "user-container"
              livenessProbe.httpGet = {
                path = "/health/liveness"
                port = 0
              }
              readinessProbe = {
                httpGet = {
                  path = "/health/readiness"
                  port = 0
                }
                successThreshold = 1
              }
              resources = func.resources
              securityContext = {
                allowPrivilegeEscalation = False
                capabilities.drop = [ "ALL" ]
                runAsNonRoot = True
                seccompProfile.type = "RuntimeDefault"
              }
            }]
          }
        }
      }
    ] for func_name, func in _config.twitch_clipz.knative.serving.functions
  ]


]
