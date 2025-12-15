import tmux.schema as schema
import yaml
import file

name = "shitcluster"

domain = "mgmt.mansion.shitcluster.io"

cluster_hosts = yaml.decode_all(file.read("../ansible/inventory.yml"))[0]

session = schema.Tmux {
  name = name
  workdir = "~/shitcluster/repo"
  windows = [
     schema.Window {
        name: "*gitops"
        panes = [
          ["*nvim"]
          ["kubectl get nodes"]
        ]
    }] + [
      schema.Window {
      name: host_name
      env.SSH_AUTH_SOCK = ""
      panes = [
        ["*ping ${name}.${domain}"]
        [
          """
          while :; do
              ssh ${name}.${domain}
              sleep 1
              echo .....
          done
          """
        ]
      ]
    } for host_name,host in cluster_hosts.all.hosts]
}
