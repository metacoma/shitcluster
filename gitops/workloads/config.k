_twitch_clipz_namespace = "twitch-clipz"

_neo4j_user = "ref+vault://kv/twitch_clipz#neo4j_user+"
_neo4j_password = "ref+vault://kv/twitch_clipz#neo4j_password+"

config = {
  nodeSelector = {
    "node-role.kubernetes.io/worker": ""
  }
  rabbitmq = {
    release_name = "rabbitmq"
    namespace = "rabbitmq"
    port = 5672
    user = "ref+vault://kv/twitch_clipz#rabbitmq_user+"
    password = "ref+vault://kv/twitch_clipz#rabbitmq_password+"
  }
  twitch_clipz = {
    namespace = _twitch_clipz_namespace
    configmap = "clipz-config"
    secret_name = "clipz-secret"

    telegram_bot = {
      app_name = "telegram-bot"
      token = "ref+vault://kv/twitch_clipz#telegram_bot_id"
      chats = {
        admin = "ref+vault://kv/twitch_clipz#telegram_admin_chat"
      }
      container_image = "metacoma/clipz-telegram-bot:latest"
      rabbitmq_exchange = "telegram-events"
    }

    clipz = {
      app_name = "clipz"
      container_image = "metacoma/clipz:latest"
      rabbitmq_exchange = "telegram-events"
    }

    download = {
      app_name = "download"
      container_image = "metacoma/clipz-download:latest"
      rabbitmq_exchange = "telegram-video-send"
    }

    clipz_twitch = {
      app_name = "clipz-twitch"
      container_image = "metacoma/clipz-twitch:latest"
      rabbitmq_exchange = "twitch-events"
    }
    timer = {
      app_name = "timer"
      container_image = "metacoma/clipz-timer:latest"
      rabbitmq_exchange = "twitch-events"
    }

#    rabbitmq = {
#      user = "${rabbitmq.user}"
#      password = "${rabbitmq.password}"
#    }

    neo4j = {
      user = _neo4j_user
      password = _neo4j_password
    }
  }
  neo4j = {
    release_name = "neo4j"
    chart_version = "4.4.44"
    namespace = _twitch_clipz_namespace
    password = _neo4j_password
  }
  ssh_tunnel = {
    ssh_args = "-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
    namespace = "network"
    container_image = "nicolaka/netshoot:latest"
    endpoints = [
      {
        name = "nl0"
        country = "NL"
        ssh = {
          user = "ref+vault://kv/vpn_nl#ssh_user"
          host = "ref+vault://kv/vpn_nl#ssh_host"
          private_key = "ref+vault://kv/vpn_nl#ssh_private_key_base64"
        }
        local_addr = "10.50.0.2/24"
        remote_addr = "10.50.0.1/24"
        remote_tun = "tun5"
        remote_tun_n = "5" # fixme
      }
    ]
  }
}
