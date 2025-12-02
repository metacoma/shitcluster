import k8s.api.core.v1 as k8core
import yaml
import file
import manifests

resources = [
    yaml.decode_all(file.read("secret.yml"))
    yaml.decode_all(file.read("pod.yml"))
]

manifests.yaml_stream([
    resources
])
