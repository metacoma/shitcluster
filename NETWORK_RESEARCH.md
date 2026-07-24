# Исследование сетевой архитектуры Kubespray + Longhorn + BGP

## Текущая конфигурация

### VLAN-топология (на каждом ноде)

| Мост | VLAN | Подсеть | Назначение сейчас |
|---|---|---|---|
| br0 | untagged | 172.23.0.0/16 | MAAS provisioning |
| br-management | 400 | 172.24.0.0/16 | Ansible, kube_vip API LB (172.24.0.48) |
| br-public | 401 | DHCP | MetalLB IP-пулы для LoadBalancer |
| br-private | 402 | 172.26.0.0/16 | `ip` / `access_ip` в inventory (всё k8s) |
| br-san | 403 | 172.27.0.0/16 | Только mcmp2/mcmp3/mcmp9 (storage nodes) |
| br-internet | 404 | 172.28.0.0/16 | Интернет (MTU 1230, туннель) |

### Что сейчас делает Kubespray

- `ip` = `access_ip` = 172.26.0.x (private VLAN) — **все** компоненты k8s привязаны к private VLAN:
  - etcd listen/advertise
  - kubelet `--node-ip`
  - Calico node IP (авто-детект из `status.hostIP`)
  - API server bind address
  - Меж-нодовый трафик подов (Calico routes)
- kube_vip на br-management (172.24.0.48) — только VIP для API server
- MetalLB Layer2 на mgmt + public VLAN

---

## Ключевые выводы из исследования

### 1. Переменные `ip` и `access_ip` в Kubespray

Из [официальной документации kubespray](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/ansible/vars.md):

- **`ip`** — IP для привязки сервисов (kubelet, apiserver advertise, Calico node IP). Обычно публичный IP.
- **`access_ip`** — IP, по которому другие ноды подключаются к этой ноде. etcd listen/advertise использует `access_ip` (если задан), иначе `ip`.

**Важно:** `ip` определяет IP-адрес, который Calico использует как node IP (через `status.hostIP` от kubelet). Это же IP используется для маршрутизации меж-нодового трафика подов.

### 2. В каком VLAN живут сервисы k8s (ClusterIP)?

**ClusterIP сервисы не живут ни в одном VLAN.** Это виртуальные IP-адреса (по умолчанию 10.233.0.0/18), которые:

- Не существуют на физическом уровне
- Реализованы через iptables/IPVS правила в ядре каждой ноды
- kube-proxy перехватывает трафик к ClusterIP и перенаправляет на pod IP
- Трафик от pod к ClusterIP никогда не покидает ноду (если pod на той же ноде) или идёт через CNI сеть (если pod на другой ноде)

**LoadBalancer сервисы (MetalLB):** получают реальные IP из пулов MetalLB. Эти IP должны быть достижимы на VLAN, где MetalLB делает announcement (Layer2 ARP или BGP).

### 3. Как разделить control-plane и pod трафик по VLAN

Проблема: переменная `ip` в kubespray контролирует **одновременно** и control-plane, и pod networking. Нельзя просто разнести их по разным VLAN через inventory.

#### Подход A: Calico BGP mode + policy routing (рекомендуемый)

```yaml
# inventory.yml — каждая нода:
ip: 172.24.0.X          # management VLAN — control-plane
access_ip: 172.24.0.X   # management VLAN — etcd тоже на management

# group_vars/all.yaml:
kube_network_plugin: calico
calico_network_backend: 'bird'        # BGP mode
calico_ipip_mode: 'Never'             # без инкапсуляции
calico_vxlan_mode: 'Never'            # без инкапсуляции
peer_with_router: true                # BGP peering с core-роутерами
nat_outgoing: false                   # не NAT-ить трафик подов
calico_advertise_cluster_ips: true    # анонсируй service ClusterIP через BGP

# Calico будет использовать management IP для BGP сессий
# Для того чтобы pod трафик шёл через private VLAN:
calico_node_extra_envs:
  FELIX_DEVICEROUTESOURCEADDRESS: "172.26.0.X"  # private IP каждой ноды (через host_var)
```

**Как это работает:**
- etcd, kube-apiserver, kube-scheduler, kube-controller-manager — все на management VLAN
- Calico BGP daemon (bird) пирингуется с core-роутерами через management VLAN
- `FELIX_DEVICEROUTESOURCEADDRESS` заставляет Calico программировать маршруты для подов с source-адресом private VLAN
- Pod трафик между нодами идёт через private VLAN (без инкапсуляции, чистый IP routing)
- Pod CIDR анонсируется через BGP в datacenter fabric

#### Подход B: Calico VXLAN over private VLAN

```yaml
ip: 172.24.0.X          # management — control-plane
access_ip: 172.24.0.X   # management — etcd

calico_network_backend: 'vxlan'
calico_vxlan_mode: 'Always'
calico_ipip_mode: 'Never'
```

**Минус:** VXLAN туннели будут использовать management IP как endpoints (так как `ip` = management). Чтобы VXLAN шёл через private, нужно оверрайдить Calico node IP, что сложно.

#### Подход C: Двойной Calico IP pool (самый чистый, но сложный)

Создать два IP pool: один для подов на private VLAN, один для всего остального. Требует кастомной конфигурации Calico за пределами kubespray.

### 4. Longhorn storage network

[Longhorn docs: Storage Network](https://longhorn.io/docs/1.9.0/advanced-resources/deploy/storage-network/)

Longhorn поддерживает выделенную storage сеть через Multus NetworkAttachmentDefinition (с версии 1.3.0):

```yaml
# 1. Создать NetworkAttachmentDefinition для SAN VLAN:
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: san-network
  namespace: longhorn-system
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "type": "macvlan",
      "master": "br-san",
      "mode": "bridge",
      "ipam": {
        "type": "static",
        "routes": [
          { "dst": "172.27.0.0/16" }
        ]
      }
    }

# 2. Установить setting в Longhorn:
kubectl patch setting.longhorn.io storage-network \
  -n longhorn-system --type merge \
  -p '{"value":"longhorn-system/san-network"}'

# Или через Helm values (longhorn_values.yml):
defaultSettings:
  storageNetwork: "longhorn-system/san-network"
```

**Важно:**
- Нужно остановить все workload'ы и открепить все volumes перед применением
- Multus уже включен у тебя (`kube_network_plugin_multus: true`)
- NAD должен быть достижим между нодами (pod на одной ноде должен пинговать pod на другой ноде через этот NAD)
- Longhorn instance-manager pod'ы получат дополнительный интерфейс eth1 на SAN сети
- Работает для block volumes (RWO) и RWX (с NFS, с версии 1.7.0)

### 5. BGP анонсирование маршрутов

#### Calico BGP для pod CIDR и service ClusterIP:

```yaml
# group_vars/all.yaml:
peer_with_router: true
nat_outgoing: false
calico_advertise_cluster_ips: true
global_as_num: "64512"

# Для каждого ноды (host_vars) или глобально (group_vars):
peers:
  - peer_ip: 172.24.0.1      # IP core-роутера на management VLAN
    as: "64513"               # AS роутера
    scope: "global"
```

#### MetalLB BGP для LoadBalancer IP:

```yaml
# group_vars/all.yaml:
metallb_enabled: true
metallb_speaker_enabled: true

metallb_config:
  address_pools:
    primary-public:
      ip_range:
        - 172.25.1.0/25
      auto-assign: false
    secondary-public:
      ip_range:
        - 172.25.1.128/25
      auto-assign: true

  layer3:
    defaults:
      peer_port: 179
      hold_time: 120s

    metallb_peers:
      peer1:
        peer_address: 172.25.0.1    # IP core-роутера
        peer_asn: 64513
        my_asn: 64512
        address_pool:
          - primary-public
          - secondary-public
```

**Альтернатива:** использовать Calico вместо MetalLB speaker для анонсирования LoadBalancer IP (Calico >= 3.18):

```yaml
metallb_speaker_enabled: false
calico_advertise_service_loadbalancer_ips:
  - 172.25.1.0/25
  - 125.1.128/25
```

---

## Рекомендуемая архитектура

```
                    ┌─────────────────────────────────────────────┐
                    │           Datacenter Core Router            │
                    │           (BGP AS 64513)                    │
                    │  172.24.0.1  │  172.26.0.1  │  172.27.0.1  │
                    └──────┬───────┴──────┬───────┴──────┬───────┘
                           │ VLAN 400     │ VLAN 402     │ VLAN 403
                           │ (management) │  (private)   │   (SAN)
                           ▼              ▼              ▼
                    ┌──────────┐   ┌──────────┐   ┌──────────┐
                    │ br-mgmt  │   │ br-priv  │   │  br-san  │
                    │172.24.0.X│   │172.26.0.X│   │172.27.0.X│
                    └────┬─────┘   └────┬─────┘   └────┬─────┘
                         │              │              │
              ┌──────────┼──────────────┼──────────────┼──────────┐
              │          │              │              │          │
              ▼          ▼              ▼              ▼          ▼
         ┌─────────┐ ┌─────────┐  ┌─────────┐  ┌─────────┐ ┌─────────┐
         │ etcd    │ │ api-    │  │ Pod     │  │Longhorn │ │ kube-   │
         │ (mgmt)  │ │ server  │  │ traffic │  │storage  │ │ let     │
         │         │ │ (mgmt)  │  │(private)│  │ (SAN)   │ │ (mgmt)  │
         │scheduler│ │         │  │         │  │         │ │         │
         │ctrl-mgr │ │kube-vip │  │Calico   │  │instance-│ │crio     │
         │(mgmt)   │ │VIP mgmt │  │BGP      │  │mgr      │ │         │
         └─────────┘ └─────────┘  └─────────┘  └─────────┘ └─────────┘
```

### Что идёт по каждому VLAN:

| VLAN | Трафик |
|---|---|
| **management (400)** | etcd peer-to-peer, kube-apiserver, kube-scheduler, kube-controller-manager, kubelet→apiserver, BGP сессии (Calico + MetalLB), Ansible SSH, kube_vip ARP |
| **private (402)** | Pod-to-pod трафик (Calico BGP, без инкапсуляции), анонсирование pod CIDR в datacenter |
| **SAN (403)** | Longhorn replica sync, instance-manager трафик (через Multus NAD) |
| **public (401)** | MetalLB LoadBalancer IP (BGP announcement или Layer2) |

---

## Конкретные изменения для inventory

### inventory.yml (пример для mcmp2):

```yaml
mcmp2:
  ansible_host: mcmp2.mgmt.mansion.shitcluster.io
  ip: 172.24.0.11           # ← management (было 172.26.0.11)
  access_ip: 172.24.0.11    # ← management (было 172.26.0.11)
  calico_node_ip: 172.24.0.11
  # Для Calico device route source:
  felix_device_route_source_address: 172.26.0.11  # private
```

### group_vars/all.yaml (добавить/изменить):

```yaml
# === Calico BGP mode ===
kube_network_plugin: calico
calico_network_backend: 'bird'
calico_ipip_mode: 'Never'
calico_vxlan_mode: 'Never'
peer_with_router: true
nat_outgoing: false
calico_advertise_cluster_ips: true
global_as_num: "64512"

# BGP peers (добавить реальные IP ваших core-роутеров):
peers:
  - peer_ip: 172.24.0.1
    as: "64513"
    scope: "global"

# Calico: pod routes через private interface
calico_node_extra_envs:
  FELIX_DEVICEROUTESOURCEADDRESS: "{{ hostvars[inventory_hostname]['felix_device_route_source_address'] | default('172.26.0.0') }}"

# === MetalLB BGP mode ===
metallb_enabled: true
metallb_speaker_enabled: true
kube_proxy_strict_arp: true

metallb_config:
  address_pools:
    primary-public:
      ip_range:
        - 172.25.1.0/25
      auto-assign: false
    secondary-public:
      ip_range:
        - 172.25.1.128/25
      auto-assign: true

  layer3:
    defaults:
      peer_port: 179
      hold_time: 120s
    metallb_peers:
      peer1:
        peer_address: 172.25.0.1    # core-роутер на public VLAN
        peer_asn: 64513
        my_asn: 64512
        address_pool:
          - primary-public
          - secondary-public

# === kube_vip (без изменений) ===
kube_vip_enabled: true
kube_vip_controlplane_enabled: true
kube_vip_address: 172.24.0.48
kube_vip_interface: br-management

# === Multus (уже есть) ===
kube_network_plugin_multus: true
```

### longhorn_values.yml (добавить):

```yaml
defaultSettings:
  storageNetwork: "longhorn-system/san-network"
```

### NetworkAttachmentDefinition для SAN (применить после деплоя k8s):

```yaml
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: san-network
  namespace: longhorn-system
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "type": "macvlan",
      "master": "br-san",
      "mode": "bridge",
      "ipam": {
        "type": "host-local",
        "subnet": "172.27.0.0/16",
        "rangeStart": "172.27.0.100",
        "rangeEnd": "172.27.0.200",
        "gateway": "172.27.0.1"
      }
    }
```

---

## Исходные материалы

### Kubespray
- [Variables documentation](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/ansible/vars.md) — `ip` vs `access_ip`
- [Calico CNI docs](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/CNI/calico.md) — BGP mode, peers, advertise
- [MetalLB docs](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/ingress/metallb.md) — BGP mode config
- [HA mode docs](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/operations/ha-mode.md) — loadbalancer_apiserver
- [Issue #6054](https://github.com/kubernetes-sigs/kubespray/issues/6054) — two interface deployment
- [Issue #5513](https://github.com/kubernetes-sigs/kubespray/issues/5513) — `access_ip` vs `ip` confusion

### Longhorn
- [Storage Network docs](https://longhorn.io/docs/1.9.0/advanced-resources/deploy/storage-network/) — Multus NAD для storage
- [Feature request #2285](https://github.com/longhorn/longhorn/issues/2285) — оригинальный запрос multi-network
- [Discussion #6476](https://github.com/longhorn/longhorn/discussions/6476) — segregation storage traffic

### Calico
- [BGP configuration](https://docs.tigera.io/calico/latest/networking/configuring/workloads-outside-cluster) — NAT outgoing
- [Overlay vs non-overlay](https://docs.tigera.io/calico/latest/networking/configuring/vxlan-ipip) — VXLAN/IPIP/BGP
- [Cisco whitepaper: Calico on-prem](https://www.cisco.com/c/en/us/td/docs/dcn/whitepapers/cisco-nx-os-calico-network-design.html) — production BGP design

### Kubernetes networking
- [Cluster networking concepts](https://kubernetes.io/docs/concepts/cluster-administration/networking/)
- [Virtual IPs and Service Proxies](https://kubernetes.io/docs/reference/networking/virtual-ips/) — как работает ClusterIP
- [Service types](https://kubernetes.io/docs/concepts/services-networking/service/)

### Статьи и блоги
- [Kubernetes on bare-metal: roll your own](https://medium.com/faun/kubernetes-on-bare-metal-roll-your-own-9ef99312df09) — VLAN separation
- [Using Calico with Kubespray](https://www.tigera.io/blog/using-calico-with-kubespray/) — официальная интеграция
- [Longhorn production optimization](https://oneuptime.com/blog/post/2026-03-20-longhorn-production-optimization/view) — dedicated storage network
