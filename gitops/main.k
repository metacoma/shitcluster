import k8s.api.core.v1 as k8core
import argoproj.v1alpha1 as argoproj
import yaml
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
            name = "reflector"
            namespace = "argocd"
        }
        spec = {
            destination = {
                namespace = "reflector"
                name = "in-cluster"
            }
            project = "default"
            source = {
                chart = "reflector"
                repoURL = "oci://ghcr.io/emberstack/helm-charts/reflector"
                targetRevision = "9.1.39"
                helm = {
                    values = yaml.encode({
                      nodeSelector = {
                        "node-role.kubernetes.io/worker": ""
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

    argoproj.Application {
        metadata = {
            name = "cert-manager"
            namespace = "argocd"
        }
        spec = {
            destination = {
                namespace = "cert-manager"
                name = "in-cluster"
            }
            project = "default"
            source = {
                chart = "cert-manager"
                repoURL = "https://charts.jetstack.io"
                targetRevision = "1.19.1"
                helm = {
                    values = yaml.encode({
                      installCRDs = True

                      #dns01RecursiveNameservers: "172.24.0.2:53,8.8.8.8:53"
                      #podAnnotations:
                      #  k8s.v1.cni.cncf.io/networks: |
                      #    [{
                      #      "name": "macvlan-management-cert-manager",
                      #      "interface": "net1",
                      #      "ips": ["172.24.1.2/24"]
                      #    }]

                      nodeSelector = {
                        "node-role.kubernetes.io/worker" = ""
                      }

                      webhook.nodeSelector = {
                        "node-role.kubernetes.io/worker" = ""
                      }

                      cainjector.nodeSelector = {
                        "node-role.kubernetes.io/worker" = ""
                      }

                      startupapicheck.nodeSelector = {
                        "node-role.kubernetes.io/worker" = ""
                      }

                    })
                    releaseName = "cert-manager"
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

]

manifests.yaml_stream([
    resources
])
