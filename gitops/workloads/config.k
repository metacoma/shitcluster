config = {
  nodeSelector = {
    "node-role.kubernetes.io/worker": ""
  }
  rabbitmq = {
    release_name = "rabbitmq"
    namespace = "rabbitmq"
    port = 5672
    user = "ref+vault://kv/twitch_clipz#rabbitmq_user"
    password = "ref+vault://kv/twitch_clipz#rabbitmq_password"
  }
  twitch_clipz = {
    namespace = "twitch-clipz"
    configmap = "clipz-config"
    secret_name = "clipz-secret"

    telegram_bot = {
      app_name = "telegram-bot"
      token = "ref+vault://kv/twitch_clipz#telegram_bot_id"
      chats = {
        admin = "ref+vault://kv/twitch_clipz#telegram_admi_chat_id"
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

    rabbitmq = {
      user = "ref+vault://kv/twitch_clipz#rabbitmq_user"
      password = "ref+vault://kv/twitch_clipz#rabbitmq_password"
    }

    neo4j = {
      user = "ref+vault://kv/twitch_clipz#neo4j_user"
      password = "ref+vault://kv/twitch_clipz#neo4j_password"
    }

  }
}
