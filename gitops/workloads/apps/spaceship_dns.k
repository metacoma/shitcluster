import k8s.api.core.v1 as k8s
import k8s.api.batch.v1 as batch
import config as cfg
import file

_config = cfg.config

namespace = "network"
name = "spaceship-dns-updater"
image = "nicolaka/netshoot:latest"

spaceship_dns = {
  domain = "ref+vault://kv/spaceship_dns#domain"
  api_key = "ref+vault://kv/spaceship_dns#api_key"
  api_secret = "ref+vault://kv/spaceship_dns#api_secret"
  api_url = "ref+vault://kv/spaceship_dns#api_url"
}

update_script = file.read("apps/spaceship_dns_update.sh")

manifests = [
  k8s.Secret {
    metadata = {
      name = name
      namespace = namespace
    }
    stringData = {
      SPACESHIP_API_URL = spaceship_dns.api_url
      SPACESHIP_API_KEY = spaceship_dns.api_key
      SPACESHIP_API_SECRET = spaceship_dns.api_secret
      SPACESHIP_DOMAIN = spaceship_dns.domain
    }
  }

  batch.CronJob {
    metadata = {
      name = name
      namespace = namespace
      labels = {
        app = name
      }
    }
    spec = {
      schedule = "*/15 * * * *"
      concurrencyPolicy = "Forbid"
      successfulJobsHistoryLimit = 3
      failedJobsHistoryLimit = 1
      jobTemplate.spec = {
        template.spec = {
          restartPolicy = "OnFailure"
          containers = [{
            name = name
            image = image
            imagePullPolicy = "IfNotPresent"
            command = ["/bin/sh", "-c", update_script]
            envFrom = [{
              secretRef.name = name
            }]
          }]
        }
      }
    }
  }
]
