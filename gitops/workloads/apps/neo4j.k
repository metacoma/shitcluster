import ..argoproj.v1alpha1 as argoproj
import yaml
import config as cfg
import template

_config = cfg.config
_neo4j = _config.neo4j

application = argoproj.Application {
  metadata = {
      name = _neo4j.release_name
      namespace = "argocd"
  }
  spec = {
      destination = {
          namespace = _neo4j.namespace
          name = "in-cluster"
      }
      project = "default"
      source = {
          chart = "neo4j-standalone"
          repoURL = "https://neo4j.github.io/helm-charts/"
          targetRevision = _neo4j.chart_version
          helm = {
              values = yaml.encode({
                disableLookups = True # https://github.com/neo4j/helm-charts/issues/290
                neo4j = {
                  resources = {
                    cpu = "2000m"
                    memory = "4Gi"
                  }
                  password = _neo4j.password
                }
                volumes = {
                  data = {
                    mode = "dynamic"
                    dynamic.storageClassName = "longhorn"
                    dynamic.requests.storage = "8Gi"
                  }
                }
                nodeSelector = _config.nodeSelector
                config = {
                  "dbms.security.procedures.whitelist" = "streams.*,apoc.*"
                  "apoc.export.file.enabled" = "true"
                  "apoc.import.file.enabled" = "true"
                  "dbms.memory.heap.initial_size" = "1G"
                  "dbms.memory.heap.max_size" = "2G"
                  "dbms.memory.pagecache.size" = "2G"
                }
              })
              releaseName = _neo4j.release_name
          }
      }
      syncPolicy = {
          automated = {
              selfHeal = True
          }
      }
  }
}
