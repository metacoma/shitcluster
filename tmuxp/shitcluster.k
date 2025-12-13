import yaml
import manifests
import .schema as tmuxp
import yaml
import file

name = "shitcluster2"

domain = "mgmt.mansion.shitcluster.io"

cluster_hosts = yaml.decode_all(file.read("../ansible/inventory.yml"))[0]

session : tmuxp.Session = {
    session_name = "shitcluster"
    start_directory = "~/shitcluster/repo"
    windows = [
        tmuxp.Window {
            "window_name": "gitops"
            panes = [
                ["nvim"]
                [""]
            ]
        }
    ] + [
        tmuxp.Window {
          "window_name": name
          panes = [
            ["ping ${name}.${domain}"]
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
        } for name,host in cluster_hosts.all.hosts
    ]
}

manifests.yaml_stream([
    session
])
