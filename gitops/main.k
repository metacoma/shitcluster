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
                        systemManagedComponentsNodeSelector = "node.longhorn.io/data-plane:true"
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

]

manifests.yaml_stream([
    resources
])
