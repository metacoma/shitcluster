import k8s.api.core.v1 as k8s
import k8s.api.apps.v1 as v1
import config as cfg

_config = cfg.config
_twitch_clipz = _config.twitch_clipz
_rabbitmq = _config.rabbitmq
_neo4j = _config.neo4j

_rabbitmq_url = "amqp://${_rabbitmq.user}:${_rabbitmq.password}@${_rabbitmq.release_name}.${_rabbitmq.namespace }:${_rabbitmq.port}/"

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
    metadata.name = _twitch_clipz.namespace
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
]
