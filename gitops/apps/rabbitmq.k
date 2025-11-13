import ..argoproj.v1alpha1 as argoproj
import yaml

application = argoproj.Application {
  metadata = {
      name = "rabbitmq"
      namespace = "argocd"
  }
  spec = {
      destination = {
          namespace = "rabbitmq"
          name = "in-cluster"
      }
      project = "default"
      source = {
          chart = "rabbitmq"
          repoURL = "oci://registry-1.docker.io/bitnamicharts/rabbitmq"
          targetRevision = "16.0.14"
          helm = {
              values = yaml.encode({
                global = {
                    security = {
                        allowInsecureImages = True
                    }
                }
                clusterDomain = "k8s.mansion.shitcluster.io"
                nodeSelector = {
                    "node-role.kubernetes.io/worker" = ""
                }
                image = {
                    repository = "bitnamilegacy/rabbitmq"
                    debug = False
                }
                volumePermissions = {
                    image = {
                        repository = "bitnamilegacy/os-shell"
                    }
                }
                fullnameOverride = "rabbitmq"
                replicaCount = 1
                auth = {
                    username = "admin"
                    password = "admin1123"
                }
                service = {
                    $type = "ClusterIP"
                }
                extraSecrets = {
                    "load-definition" = {
                        "load_definition.json" = r"""{
              "rabbit_version": "any",
              "vhosts": [
                { "name": "/" }
              ],
              "users": [
                {
                  "name": "admin",
                  "password": "admin1123",
                  "tags": "administrator"
                }
              ],
              "permissions": [
                {
                  "user": "admin",
                  "vhost": "/",
                  "configure": ".*",
                  "write": ".*",
                  "read": ".*"
                }
              ],
              "exchanges": [
                {
                  "name": "telegram-events",
                  "vhost": "/",
                  "type": "fanout",
                  "durable": true,
                  "auto_delete": false,
                  "internal": false,
                  "arguments": {}
                },
                {
                  "name": "twitch-events",
                  "vhost": "/",
                  "type": "fanout",
                  "durable": true,
                  "auto_delete": false,
                  "internal": false,
                  "arguments": {}
                },
                {
                  "name": "telegram-video-send",
                  "vhost": "/",
                  "type": "fanout",
                  "durable": true,
                  "auto_delete": false,
                  "internal": false,
                  "arguments": {}
                }
              ],
              "queues": [
                {
                  "name": "telegram-events",
                  "vhost": "/",
                  "durable": true,
                  "auto_delete": false,
                  "arguments": {}
                },
                {
                  "name": "twitch-events",
                  "vhost": "/",
                  "durable": true,
                  "auto_delete": false,
                  "arguments": {}
                },
                {
                  "name": "telegram-video-send",
                  "vhost": "/",
                  "durable": true,
                  "auto_delete": false,
                  "arguments": {}
                }
              ],
              "bindings": [
                {
                  "source": "telegram-events",
                  "vhost": "/",
                  "destination": "telegram-events",
                  "destination_type": "queue",
                  "routing_key": "*",
                  "arguments": {}
                },
                {
                  "source": "twitch-events",
                  "vhost": "/",
                  "destination": "twitch-events",
                  "destination_type": "queue",
                  "routing_key": "*",
                  "arguments": {}
                },
                {
                  "source": "telegram-video-send",
                  "vhost": "/",
                  "destination": "telegram-video-send",
                  "destination_type": "queue",
                  "routing_key": "*",
                  "arguments": {}
                }
              ],
              "policies": []
            }
            """
                    }
                }
                loadDefinition = {
                    enabled = True
                    existingSecret = "load-definition"
                }
                extraConfiguration = r"""load_definitions = /app/load_definition.json
            """
              })
              releaseName = "rabbitmq"
          }
      }
      syncPolicy = {
          automated = {
              selfHeal = True
          }
          syncOptions = [
              "CreateNamespace=true"
          ]
      }
  }
}
