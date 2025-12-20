import yaml
import manifests
import tmux.schema as schema
import file
import gitops.workloads.config as config
import tmux.shell

_config = config.config
ssh_tunnel = _config.ssh_tunnel
endpoints = ssh_tunnel.endpoints

debug = False


k = "kubectl -n ${ssh_tunnel.namespace}"

ssh_cmd = "ssh ${ssh_tunnel.ssh_args} -i /root/.ssh/private_key -l $SSH_TUNNEL_USER $SSH_TUNNEL_HOST"

mgmt_domain = "mgmt.mansion.shitcluster.io"

exec = lambda deployment_name : str, cmd : str -> str {
  "${k} exec -ti deployment/${deployment_name} -- ${cmd}"
}


pod_ip_cmd = lambda endpoint_name : str -> str {
  exec("ssh-tunnel-" + endpoint_name, "ip -4 a show dev public | awk '/inet/ {print \$2}'")
}

sessions = [
  schema.Tmux {
  name = "ssh-tunnel-${endpoint.name}"
  before = [
    shell.alias("pod", exec("ssh-tunnel-" + endpoint.name, "$*"))
    shell.alias("pod_ip", pod_ip_cmd(endpoint.name))
  ]
  windows = [
    schema.Window {
      name = "*pod"
      layout = "0aac,136x34,0,0[136x17,0,0{68x17,0,0,0,67x17,69,0[67x8,69,0,3,67x8,69,9,4]},136x16,0,18{68x16,0,18,1,67x16,69,18,2}]"
      panes = [
        [ "watch '${k} get pod -o wide -l app=ssh-tunnel-${endpoint.name}'"]
        [ "pod ping ${endpoint.remote_addr[:-3]}" ]
        [
          "ip ro get 8.8.8.8"
          "pod_ip"
        ]
        [
          "pod /bin/bash"
          "ip a show dev public"
        ]
        [
          "pod /bin/bash"
          "${ssh_cmd}"
        ]
       ]
    }
    schema.Window {
      name = endpoint.name
      panes = [
        [
          "pod /bin/bash"
          "${ssh_cmd}"
        ]
        [
          "pod /bin/bash"
          "${ssh_cmd}"
        ]
       ]
    }
    schema.Window {
      name = "traffic"
      panes = [
        [
          "pod /bin/bash"
          "pkill -9 -f iptraf-ng"
          "rm /var/run/iptraf-ng.pid"
          "iptraf-ng -d tun0"
        ]
      ]
    }
    schema.Window {
      name = "pod-node"
      panes = [
        [
          "pod /bin/bash"
        ]
        [
          "WORKER_NODE=$(kubectl get pod -n ${ssh_tunnel.namespace} -l app=ssh-tunnel-${endpoint.name} -o jsonpath='{.items[0].spec.nodeName}')"
          "ssh -t $WORKER_NODE.${mgmt_domain}"
        ]
        [
          "pod /bin/bash"
          "${ssh_cmd}"
        ]
      ]
    }
    if debug:
      schema.Window {
        name = "tcpdump"
        panes = [
          [
            "pod /bin/bash"
            "tcpdump -ni tun0"
          ]
          [
            "pod /bin/bash"
            "${ssh_cmd}"
            "tcpdump -ni ${endpoint.remote_tun}"
          ]
         ]
      }
  ]
 } for endpoint in endpoints

]
