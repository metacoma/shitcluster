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
                      csi = {
                        enabled = True
                        pod.nodeSelector = {
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
                          postStart = [
                              "sh"
                              "-c"
                              r"""sleep 60
                  echo "Try to unseal..."
                  vault status > /tmp/status.txt
                  if ! vault status >/dev/null 2>&1; then
                    echo "Initializing Vault..."
                    vault operator init -key-shares=1 -key-threshold=1 > /vault/data/init.txt
                    UNSEAL_KEY=$(grep 'Unseal Key 1:' /vault/data/init.txt | awk '{print $4}')
                    vault operator unseal $UNSEAL_KEY
                    echo "Root token:"
                    grep 'Initial Root Token:' /vault/data//init.txt | awk '{print $4}'
                    # rm /tmp/init.txt
                  fi
                  vault status >> /tmp/status.txt
                  echo "Done..."
                  """
                          ]
                      }
                    })
                    releaseName = "vault"
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
            name = "csi-secrets-store"
            namespace = "argocd"
        }
        spec = {
            destination = {
                namespace = "kube-system"
                name = "in-cluster"
            }
            project = "default"
            source = {
                chart = "secrets-store-csi-driver"
                repoURL = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
                targetRevision = "1.5.4"
                helm = {
                    values = yaml.encode({
                      linux = {
                        image.repository = "k8s.m.daocloud.io/csi-secrets-store/driver"
                        nodeSelector = {
                          "node-role.kubernetes.io/worker" = ""
                        }
                        crds.image.repository = "k8s.m.daocloud.io/csi-secrets-store/driver-crds"
                        registrarImage.repository = "k8s.m.daocloud.io/sig-storage/csi-node-driver-registrar"
                        livenessProbeImage.repository = "k8s.m.daocloud.io/sig-storage/livenessprobe"
                      }
                    })

                    releaseName = "csi-secrets-store"
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
