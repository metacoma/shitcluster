import k8s.api.core.v1 as k8s
import k8s.api.apps.v1 as v1
import config as cfg

_config = cfg.config
_ssh_tunnel = _config.ssh_tunnel

ssh_tunnel_resource_name = lambda endpoint -> str {
  "ssh-tunnel-${endpoint.name}"
}

ssh_tunnel_secret_name = lambda endpoint -> str {
  ssh_tunnel_resource_name(endpoint)
}

ssh_tunnel_private_key_secret_name = lambda endpoint -> str {
  ssh_tunnel_resource_name(endpoint) + "-private-key"
}

makeDeployment = lambda endpoint : any -> v1.Deployment {
  v1.Deployment {
    metadata = {
      name = ssh_tunnel_resource_name(endpoint)
      namespace = _ssh_tunnel.namespace
      labels = {
        app = ssh_tunnel_resource_name(endpoint)
      }
    }
    spec = {
      selector.matchLabels = {app = ssh_tunnel_resource_name(endpoint) }
      template = {
        metadata.labels = {app = ssh_tunnel_resource_name(endpoint) }
        spec = {
          nodeSelector = _config.nodeSelector
          containers = [{
            name = ssh_tunnel_resource_name(endpoint)
            image = _ssh_tunnel.container_image
            imagePullPolicy = "IfNotPresent"
            envFrom = [
              { secretRef.name = ssh_tunnel_secret_name(endpoint) }
            ]
            volumeMounts = [{
              name = "ssh-private-key"
              mountPath = "/root/.ssh"
              readOnly = True
            }]
          }]
          volumes = [{
            name = "ssh-private-key"
            secret = {
              secretName = ssh_tunnel_private_key_secret_name(endpoint)
              defaultMode = 0400
            }
          }]
        }
      }
    }
  }

}


manifests = [
  k8s.Namespace {
    metadata.name = _ssh_tunnel.namespace
  }
  [
    [
      k8s.Secret {
        metadata = {
          name = ssh_tunnel_secret_name(endpoint)
          namespace = _ssh_tunnel.namespace
        }
        stringData = {
          SSH_TUNNEL_USER = endpoint.ssh.user
          SSH_TUNNEL_HOST = endpoint.ssh.host
        }
      }
      k8s.Secret {
        metadata = {
          name = ssh_tunnel_private_key_secret_name(endpoint)
          namespace = _ssh_tunnel.namespace
        }
        data = {
          private_key = endpoint.ssh.private_key
        }
      }
      makeDeployment(endpoint)
    ] for endpoint in _ssh_tunnel.endpoints
  ]
]
