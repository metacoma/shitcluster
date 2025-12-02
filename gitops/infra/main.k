import argoproj.v1alpha1 as argoproj
import yaml
import json
import file
import manifests

resources = [
  yaml.decode_all(file.read("tekton-pipelines.yml"))
]

manifests.yaml_stream([
  resources
])
