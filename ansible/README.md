# Ansible Playbooks

## Prerequisites

- **Python ≥ 3.11** (required by `ansible==11.13.0` / kubespray v2.31.0)
- SSH key for cluster nodes (default: `/home/ubuntu/shitcluster/maas/maas_id`)

### Installing Python 3.11+ on Ubuntu 22.04

```bash
# Ubuntu 22.04 ships Python 3.10 by default — add deadsnakes PPA:
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt update
sudo apt install -y python3.11 python3.11-venv python3.11-distutils
```

On Ubuntu 24.04+, Python 3.12 is available in the default repos:

```bash
sudo apt install -y python3.12 python3.12-venv
```

## Setup

```bash
cd ansible

# Create venv (automatically picks python3.11+ if available)
make venv2

# Install Python dependencies + ansible galaxy roles
make ansible_requirements

# Verify connectivity
make ansible_ping
```

## Playbooks

| Target | Description |
|---|---|
| `make kubernetes` | Full flow: network → cloud-init → storage → k8s → macvlan |
| `make kubespray` | Kubernetes only (kubespray cluster) |
| `make reset` | Reset kubernetes (kubespray reset) |
| `make network` | Apply netplan configuration |
| `make disable_cloud_init_network` | Prevent cloud-init from overwriting netplan |
| `make longhorn` | Install longhorn dependencies (iscsi, nfs, etc.) |
| `make macvlan_dhcp` | Enable CNI DHCP daemon |
| `make fix_dns` | Fix DNS configuration |
