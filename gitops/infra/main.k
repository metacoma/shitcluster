import argoproj.v1alpha1 as argoproj
import yaml
import json
import file
import manifests

resources = [
    argoproj.Application {
        metadata = {
            name = "longhorn"
            namespace = "argocd"
        }
        spec = {
            destination = {
                namespace = "longhorn-system"
                #server = "https://kubernetes.default.svc"
                name = "in-cluster"
            }
            project = "default"
            source = {
                chart = "longhorn"
                repoURL = "https://charts.longhorn.io"
                targetRevision = "1.10.1"
                helm = {
                    values = yaml.encode({
                      service.ui = {
                        type = "LoadBalancer"
                        loadBalancerIP: "172.25.1.3"
                      }

                      defaultSettings = {
                        createDefaultDiskLabeledNodes = "true"
                        #systemManagedComponentsNodeSelector = "node.longhorn.io/data-plane:true"
                        defaultDataPath = "/storage"
                      }

                      longhornUI = {
                        replicas: 1
                        tolerations = [{
                          key = "node-role.kubernetes.io/control-plane"
                          operator = "Equal"
                          value: ""
                          effect = "NoSchedule"
                        }]
                      }
                      # https://longhorn.io/docs/1.10.1/deploy/install/install-with-argocd/
                      preUpgradeChecker.jobEnabled = False
                    })

                    releaseName = "longhorn"
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

    argoproj.Application {
        metadata = {
            name = "vault"
            namespace = "argocd"
        }
        spec = {
            destination = {
                namespace = "vault"
                name = "in-cluster"
            }
            project = "default"
            source = {
                chart = "vault"
                repoURL = "https://helm.releases.hashicorp.com"
                targetRevision = "0.31.0"
                helm = {
                    values = yaml.encode({
                      global = {
                          tolerations = [
                              {
                                  key = "node-role.kubernetes.io/control-plane"
                                  operator = "Equal"
                                  value = ""
                                  effect = "NoSchedule"
                              }
                          ]
                      }
                      ui = {
                          enabled = True
                          serviceType = "LoadBalancer"
                          loadBalancerIP = "172.25.1.4"
                      }
                      injector = {
                          nodeSelector = {
                              "node-role.kubernetes.io/worker" = ""
                          }
                      }
                      server = {
                          nodeSelector = {
                              "node-role.kubernetes.io/worker" = ""
                          }
                          dataStorage = {
                              size = "4Gi"
                          }
                          ingress = {
                              enabled = True
                              annotations = {
                                  "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
                                  "cert-manager.io/cluster-issuer" = "letsencrypt"
                                  "cert-manager.io/secret-template" = r"""{"annotations": {"reflector.v1.k8s.emberstack.com/reflection-allowed": "true", "reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces": ""}}
                  """
                              }
                              hosts = [
                                  {
                                      host = "vault-api.mansion.metacoma.org"
                                      paths = [
                                      ]
                                  }
                              ]
                              tls = [
                                  {
                                      hosts = [
                                          "vault-api.mansion.metacoma.org"
                                      ]
                                      secretName = "mansion-wildcard"
                                  }
                              ]
                          }
                      }
                    })
                    releaseName = "reflector"
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

    yaml.decode_all(file.read("tekton-pipelines.yml"))
]

manifests.yaml_stream([
  resources
])
