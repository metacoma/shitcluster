import .tmux.sessions.shitcluster as shitcluster
import .tmux.sessions.ssh_tunnels as ssh_tunnels
import .tmux.sessions.bird as bird
import .tmux.sessions.twitch_clipz as twitch_clipz
import .tmux.tmuxp as tmuxp
import manifests


manifests.yaml_stream([
  tmuxp.render(shitcluster.session)
  tmuxp.renders(ssh_tunnels.sessions)
  tmuxp.renders(twitch_clipz.sessions)
])
