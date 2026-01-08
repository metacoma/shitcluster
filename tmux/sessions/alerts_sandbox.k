import manifests
import tmux.schema as schema
import tmux.shell as shell
import yaml
import json
import file

session_name = "alerts-sandbox"

secrets = yaml.decode(file.read("./secrets/vault_data.yaml")).vault_data

vector = {
  image = {
    repo = "timberio/vector"
    tag = "0.50.0-alpine"
  }
  container_name = "vector"
}

alertmanager = {
  image = {
    repo = "prom/alertmanager"
    tag = "v0.30.0"
  }
  container_name = "alertmanager"
}

files = {
  vector_config = "vector.yaml"
  alertmanager_config = "alertmanager.yml"
  example_data = "example.log"
}

vector_monitoring_config = {
    sources = {
        example_log = {
            $type = "file"
            include = [
                "/data/${files.example_data}"
            ]
            read_from = "beginning"
        }
    }
    transforms = {
        only_xxx = {
            $type = "filter"
            inputs = [
                "example_log"
            ]
            condition = r"""
contains(string!(.message), "XXX")
"""
        }
        alertmanager_payload = {
            $type = "remap"
            inputs = [ "only_xxx" ]
            source = """
alert = {
  "labels": {
    "alertname": "PythonTracebackDetected",
    "pod_name":  "twitch-clipz-deployment-00001",
    "namespace": "twitch-clipz",
    "container_name": "user-container",
    "hostname": "mcmp6",
    "severity": "critical"
  },
  "annotations": {
    "summary": "PythonTraceBack",
    "description": to_string(.message) ?? ""
  },
  "startsAt": format_timestamp!(now(), format: "%+")
}
. = alert
"""
        }
    }
    sinks = {
        to_alertmanager = {
            $type = "http"
            inputs = [
                "alertmanager_payload"
            ]
            method = "post"
            uri = "http://alertmanager:9093/api/v2/alerts"
            headers = {
                "Content-Type" = "application/json"
            }
            encoding.codec = "json"
            batch = {
                max_events = 1
                timeout_secs = 1
            }
        }
        stdout = {
            $type = "console"
            inputs = [
                "alertmanager_payload"
            ]
            encoding = {
                codec = "json"
                text = {
                    field = "alert"
                }
            }
        }
    }
}

alert_manager_config = {
    global = {
    }
    receivers = [
        {
            name = "telegram-twitch-monitoring"
            telegram_configs = [
                {
                    bot_token = secrets.twitch_clipz.telegram_bot_id
                    chat_id = int(secrets.twitch_clipz.telegram_monitoring_chat)
                    message = r"""
🚨 *{{ .CommonLabels.alertname }}*  ({{ .CommonLabels.severity }})

*Where*
• ns: `{{ .CommonLabels.namespace }}`
• pod: `{{ .CommonLabels.pod_name }}/{{ .CommonLabels.container_name }}`
• node: `{{ .CommonLabels.hostname }}`

*What*
• {{ (index .Alerts 0).Annotations.summary }}

*Traceback*
```{{ (index .Alerts 0).Annotations.description }}```
"""
                    parse_mode = "Markdown"
                    send_resolved = False
                }
            ]
        }
    ]
    route = {
        group_by = [
            "alertname"
            "severity"
            "namespace"
        ]
        group_interval = "5m"
        group_wait = "10s"
        receiver = "telegram-twitch-monitoring"
        repeat_interval = "3h"
    }
    templates = [
        "/etc/alertmanager/*.tmpl"
    ]
}

vector_input_data = """
test
XXX
test
"""


sessions = [
  schema.Tmux {
  name = "alerts-sandbox"
  workdir = "~/tmp/${name}"
  before = [
    "test -d ${workdir} || mkdir -p ${workdir}"
    shell.alias("run_test", shell.text_file_append(files.example_data, vector_input_data))
  ]

  windows = [
     schema.Window {
        name: "*main"
        panes = [
          [
            shell.yaml_file(files.vector_config, vector_monitoring_config)
            shell.text_file(files.example_data, vector_input_data)
            """
  sudo nerdctl rm -f ${vector.container_name}; \
  sudo nerdctl run --rm -it \
  --name ${vector.container_name} \
  -v "`pwd`/${files.vector_config}:/etc/vector/vector.yaml:ro" \
  -v "`pwd`/${files.example_data}:/data/example.log:ro" \
  ${vector.image.repo}:${vector.image.tag}
"""
          ]
          [
            shell.yaml_file(files.alertmanager_config, alert_manager_config)
            """
  sudo nerdctl rm -f ${alertmanager.container_name}; \
  sudo nerdctl run --rm -it \
  --name ${alertmanager.container_name} \
  -p 9093:9093 \
  -v "`pwd`/${files.alertmanager_config}:/etc/alertmanager/alertmanager.yml:ro" \
  ${alertmanager.image.repo}:${alertmanager.image.tag} \
  --config.file=/etc/alertmanager/alertmanager.yml
"""
          ]
          [
          shell.wait_for_file(v)
          for k,v in files
          ] + [
            shell.wait_for_cmd("sudo nerdctl ps | grep \'Up .* ${vector.container_name}\'")
            shell.wait_for_cmd("sudo nerdctl ps | grep \'Up .* ${alertmanager.container_name}\'")
          ]
        ]
      }
    ]
  }
]
