import argoproj.v1alpha1 as argoproj
import yaml
import json
import file
import manifests
import json_merge_patch as json_patch

needNodeSelector = ["ReplicaSet", "Pod", "Deployment"]

resources = [
  [
    [
        if resource:
            if resource.kind in needNodeSelector :
                if resource.kind in ["Deployment", "ReplicaSet"]:
                    json_patch.merge(resource, {
                      spec.template.spec.nodeSelector = {
                        "node-role.kubernetes.io/worker" = ""
                      }
                    })
                else:
                    json_patch.merge(resource, {
                      metadata.nodeSelector = {
                        "node-role.kubernetes.io/worker" = ""
                      }
                    })
            else:
                resource
    ]
    for resource in yaml.decode_all(file.read("tekton-pipelines.yml"))
  ]
]

manifests.yaml_stream([
  resources
])
