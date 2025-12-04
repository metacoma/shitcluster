import ..argoproj.v1alpha1 as argoproj
import yaml
import config as cfg
import template

_config = cfg.config
_rabbitmq = _config.rabbitmq

application = argoproj.Application {
  metadata = {
      name = _rabbitmq.release_name
      namespace = "argocd"
  }
  spec = {
      destination = {
          namespace = _rabbitmq.namespace
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
                nodeSelector = _config.nodeSelector
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
                    username = _rabbitmq.user
                    password = _rabbitmq.password
                }
                service = {
                    $type = "ClusterIP"
                }
                extraSecrets = {
                    "load-definition" = {
                        "load_definition.json" = template.execute("""{
                            "rabbit_version": "any",
                            "vhosts": [
                              { "name": "/" }
                            ],
                            "users": [
                              {
                                "name": "{{ user }}",
                                "password": "{{ password}}",
                                "tags": "administrator"
                              }
                            ],
                            "permissions": [
                              {
                                "user": "{{ user }}",
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
                          """, {
                            user = _rabbitmq.user
                            password = _rabbitmq.password
                          })
                    }
                }
                loadDefinition = {
                    enabled = True
                    existingSecret = "load-definition"
                }
                extraConfiguration = "load_definitions = /app/load_definition.json"
              })
              releaseName = _rabbitmq.release_name
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
