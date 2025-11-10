import k8s.api.core.v1 as k8core
import argoproj.v1alpha1 as argoproj
import yaml
import manifests

resources = [
    argoproj.Application {
        metadata = {
            name = "ingress-nginx"
            namespace = "ingress-nginx"
        }
        spec = {
            destination = {
                namespace = "ingress-nginx"
                server = "https://kubernetes.default.svc"
            }
            project = "default"
            source = {
                chart = "ingress-nginx"
                repoURL = "https://kubernetes.github.io/ingress-nginx"
                targetRevision = "4.14.0"
                helm = {
                    values = yaml.encode({
                        global.image.registry: "k8s.m.daocloud.io"
                        controller.service.loadBalancerIP = "172.24.1.1"
                    })

                    releaseName = "ingress-nginx"
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


    # argoproj.Application {
    #     metadata = {
    #         name = "longhorn"
    #         namespace = "longhorn-system"
    #     }
    #     spec = {
    #         destination = {
    #             namespace = "longhorn-system"
    #             server = "https://kubernetes.default.svc"
    #         }
    #         project = "default"
    #         source = {
    #             chart = "longhorn"
    #             repoURL = "https://charts.longhorn.io"
    #             # targetRevision = "4.14.0"
    #             helm = {
    #                 values = yaml.encode({
    #                     service.ui.type = "LoadBalancer"
    #                     service.ui.loadBalancerIP = "172.24.1.3"
    #                     longhornUI = {
    #                         replicas = 1
    #                         tolerations = [{
    #                           key = "node-role.kubernetes.io/control-plane"
    #                           operator = "Equal"
    #                           value = ""
    #                           effect = "NoSchedule"
    #                         }]
    #                     }
    #                     defaultSettings.defaultDataPath = "/storage"
    #                 })
    #
    #                 releaseName = "longhorn"
    #             }
    #         }
    #         syncPolicy = {
    #             automated = {
    #                 selfHeal = True
    #             }
    #             syncOptions = [
    #                 "CreateNamespace=true"
    #             ]
    #         }
    #     }
    # }
    #


    # k8core.Namespace {
    #                 metadata.name = "longhorn-system"
    # }
    k8core.Namespace {
                    metadata.name = "test1"
    }
    k8core.Namespace {
                    metadata.name = "test2"
    }
]
]

manifests.yaml_stream([
    resources
])
