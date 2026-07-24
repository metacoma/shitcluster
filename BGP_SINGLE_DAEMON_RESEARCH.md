# Deep Research: Один BGP демон (Calico bird) для Calico + MetalLB

## Краткий ответ

**Да, это возможно и официально поддерживается.** Начиная с Calico 3.18 (early 2021), Calico может анонсировать LoadBalancer IP через BGP, полностью заменяя MetalLB speaker. MetalLB остаётся только в режиме controller-only (для аллокации IP из пулов), а весь BGP делает Calico bird.

---

## 1. Архитектура: Calico bird как единственный BGP демон

### Проблема двух BGP демонов

До Calico 3.18 на каждой ноде работали два независимых BGP спикера:
- **Calico bird** — анонсировал pod CIDR и service ClusterIP
- **MetalLB speaker (FRR)** — анонсировал LoadBalancer IP

**Проблема:** BGP позволяет только одну сессию между парой узлов. Если Calico уже заперился с ToR-роутером, MetalLB не может установить свою сессию — она будет отклонена как дубликат.

[Источник: metallb.universe.tf/configuration/calico/](https://metallb.universe.tf/configuration/calico/)

### Решение: Calico 3.18+ serviceLoadBalancerIPs

Calico 3.18+ добавил поддержку `serviceLoadBalancerIPs` в `BGPConfiguration` CRD. Теперь Calico bird может анонсировать:
1. Pod CIDR (всегда)
2. Service ClusterIP (через `serviceClusterIPs`)
3. **Service LoadBalancer IP** (через `serviceLoadBalancerIPs`) ← это новое

MetalLB speaker можно полностью удалить. MetalLB controller остаётся — он только управляет аллокацией IP из пулов, без BGP.

```
┌──────────────────────────────────────────────────┐
│                  Node mcmp2                       │
│                                                   │
│  ┌─────────────────────────────────────────────┐ │
│  │  Calico bird (ОДИН BGP демон)               │ │
│  │  ┌───────────────────────────────────────┐  │ │
│  │  │ Анонсируемые префиксы:                │  │ │
│  │  │  • 10.233.64.0/18  (pod CIDR)         │  │ │
│  │  │  • 10.233.0.0/18   (service ClusterIP)│  │ │
│  │  │  • 172.24.1.0/25   (LB pool mgmt)     │  │ │
│  │  │  • 172.25.1.0/25   (LB pool public)   │  │ │
│  │  └───────────────────────────────────────┘  │ │
│  │  BGP peer → 172.24.0.1 (AS 64513)           │ │
│  └─────────────────────────────────────────────┘ │
│                                                   │
│  MetalLB controller (только IP allocation)        │
│  MetalLB speaker — УДАЛЁН                         │
│                                                   │
└───────────────────────────────────────────────────┘
         │
         ▼ BGP session (TCP 179)
┌──────────────────┐
│ Core Router      │
│ 172.24.0.1       │
│ AS 64513         │
└──────────────────┘
```

---

## 2. Как это работает в Kubespray

### Kubespray переменные

Kubespray имеет встроенную поддержку этой архитектуры:

```yaml
# Отключить MetalLB speaker
metallb_speaker_enabled: false

# Включить Calico advertisement для LB IP
calico_advertise_service_loadbalancer_ips:
  - 172.24.1.0/25
  - 172.24.1.128/25
  - 172.25.1.0/25
  - 172.25.1.128/25
```

Kubespray автоматически создаст `BGPConfiguration` CRD с `serviceLoadBalancerIPs` полем, содержащим указанные CIDR.

[Источник: kubespray/docs/ingress/metallb.md](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/ingress/metallb.md)

### Что делает Kubespray под капотом

Kubespray calico role создаёт следующие CRD:

```yaml
apiVersion: projectcalico.org/v3
kind: BGPConfiguration
metadata:
  name: default
spec:
  asNumber: "64512"
  nodeToNodeMeshEnabled: false  # если peer_with_router: true
  serviceClusterIPs:            # если calico_advertise_cluster_ips: true
    - cidr: 10.233.0.0/18
  serviceLoadBalancerIPs:       # если calico_advertise_service_loadbalancer_ips задан
    - cidr: 172.24.1.0/25
    - cidr: 172.24.1.128/25
    - cidr: 172.25.1.0/25
    - cidr: 172.25.1.128/25
```

И BGPPeer для каждого peer из `peers` переменной:

```yaml
apiVersion: projectcalico.org/v3
kind: BGPPeer
metadata:
  name: kubespray-bgpeers-global
spec:
  peerIP: 172.24.0.1
  asNumber: 64513
  # sourceAddress: "UseNodeIP"  # default
```

---

## 3. Критический вопрос: один BGP peer для двух VLAN?

### Ситуация

У тебя:
- BGP peer на **management VLAN**: `172.24.0.1`
- LB IP пулы на **management VLAN**: `172.24.1.0/25`
- LB IP пулы на **public VLAN**: `172.25.1.0/25`

Calico bird на каждой ноде имеет `ip` = `172.24.0.X` (management). BGP сессия идёт к `172.24.0.1`.

**Вопрос:** Может ли Calico через одну BGP сессию на management VLAN анонсировать префиксы из public VLAN (`172.25.1.0/25`)?

### Ответ: Да, BGP не привязан к VLAN

BGP — это L3 протокол. BGP сессия — это TCP соединение между двумя IP-адресами. Через одну BGP сессию можно анонсировать **любые** IP-префиксы, независимо от того, в каком VLAN они находятся.

**Но есть важное условие:** роутер-пир (`172.24.0.1`) должен знать, как доставить трафик до анонсированных префиксов. Когда Calico анонсирует `172.25.1.0/25` через BGP сессию на management VLAN:

1. Роутер получает маршрут: `172.25.1.0/25 → next-hop: 172.24.0.11` (management IP ноды)
2. Роутер должен иметь маршрутизацию между management и public VLAN
3. Трафик от внешних клиентов: клиент → роутер → management VLAN → нода → kube-proxy → pod

**Это работает, если:**
- Роутер `172.24.0.1` имеет маршруты между VLAN (обычно так и есть, это L3 роутер)
- Нода может принять трафик на management интерфейсе, destined для public IP (требует правильной настройки rp_filter)

### Альтернатива: два BGP peer'а через один bird

Если роутер не маршрутизирует между VLAN, или ты хочешь более чистую архитектуру, Calico bird поддерживает **несколько BGP peer'ов** через одну демон-инстанцию:

```yaml
# В kubespray peers variable:
peers:
  - peer_ip: 172.24.0.1    # management VLAN
    as: "64513"
    scope: "global"
  - peer_ip: 172.25.0.1    # public VLAN (если роутер доступен оттуда)
    as: "64513"
    scope: "global"
    source_address: "None"  # bird сам выберет source IP
```

**НО:** Calico bird использует node IP (`ip` = `172.24.0.X`) как source address для всех BGP сессий по умолчанию. Для peer'а на `172.25.0.1` (public VLAN) это не сработает — TCP SYN пойдёт от `172.24.0.X`, и роутер на public VLAN не ответит.

Решение: `sourceAddress: "None"` в BGPPeer — bird сам выберет source IP на основе маршрутизации. Но это требует, чтобы на ноде был маршрут до `172.25.0.1` через public интерфейс.

[Источник: Calico BGPPeer sourceAddress field](https://docs.tigera.io/calico/latest/reference/resources/bgppeer)
[Источник: GitHub issue #5226 — multi-interface BGP source address](https://github.com/projectcalico/calico/issues/5226)

---

## 4. Проблема VIP binding и ARP

### Самая важная проблема production

Когда Calico анонсирует LB IP через BGP (без MetalLB speaker), **ни одна нода не привязывает VIP к своему интерфейсу**. Calico bird только анонсирует маршрут через BGP, но не делает:
- Привязку IP к интерфейсу
- Gratuitous ARP
- Ответы на ARP запросы

[Источник: AHdark Blog — Analyzing Load Balancer VIP Routing](https://www.ahdark.blog/analyzing-load-balancer-vip-routing/)

### Что происходит на практике

**Сценарий 1: BGP роутер на том же L2 сегменте (твой случай для management)**

```
Клиент на management VLAN → ARP "кто 172.24.1.50?" → НИКТО НЕ ОТВЕЧАЕТ
```

Решение: MetalLB speaker в L2 mode (не BGP mode) может отвечать на ARP. Но мы его отключили.

**Варианты решения:**

| Решение | Плюсы | Минусы |
|---|---|---|
| **Оставить MetalLB speaker в L2 mode** | ARP работает, просто отключить FRR/BGP в speaker | Два демона, но без конфликта BGP сессий |
| **kube-vip для LB IP** | Уже используешь для API server | Дополнительная настройка |
| **BGP + роутер делает NAT/proxy-ARP** | Чисто, один BGP демон | Требует настройки на роутере |
| **Calico eBPF mode** | Calico сам обрабатывает сервисы | Сложная миграция, другой dataplane |

### Рекомендуемый подход для твоей инфраструктуры

Так как у тебя BGP роутер (`172.24.0.1`) на том же L2 сегменте (management VLAN), и роутер получает BGP маршруты от Calico:

**Для management LB пулов (`172.24.1.0/25`):**
- Роутер узнаёт маршрут `172.24.1.0/25 → next-hop: 172.24.0.11` через BGP
- Роутер сам маршрутизирует трафик: клиент на management VLAN → роутер → нода
- ARP не нужен между клиентом и нодой — клиент шлёт на роутер (шлюз по умолчанию)
- **Работает без дополнительных настроек** ✓

**Для public LB пулов (`172.25.1.0/25`):**
- Те же BGP маршруты идут через ту же сессию на management
- Роутер узнаёт `172.25.1.0/25 → next-hop: 172.24.0.11`
- Роутер маршрутизирует: клиент на public VLAN → роутер → management VLAN → нода
- **Работает, если роутер маршрутизирует между VLAN** ✓

**Вывод:** В твоей архитектуре (центральный L3 роутер между всеми VLAN) BGP-only подход работает без ARP проблем, потому что все клиенты шлют трафик через роутер, а не напрямую на ноды.

---

## 5. Ограничения и нюансы Calico LB advertisement

### Calico анонсирует весь CIDR, не отдельные IP

Когда ты задаёшь `serviceLoadBalancerIPs: [{cidr: "172.24.1.0/25"}]`, Calico анонсирует **весь /25 префикс**, а не конкретные назначенные IP. Это значит:
- Роутер получает один маршрут `/25` на каждую ноду
- С ECMP на роутере — нагрузка распределяется между нодами
- Без ECMP — весь трафик `/25` идёт на одну ноду

[Источник: metallb.universe.tf/configuration/calico/](https://metallb.universe.tf/configuration/calico/)

### externalTrafficPolicy поведение

| Mode | Что анонсирует Calico | Source IP | Load balancing |
|---|---|---|---|
| `Cluster` (default) | Весь CIDR (`/25`) со всех нод | SNAT (теряется) | ECMP на роутере |
| `Local` | Конкретный IP (`/32`) только с нод, где есть pod | Сохраняется | Только ноды с endpoint |

Рекомендация: используй `externalTrafficPolicy: Local` для сохранения source IP.

### rp_filter на нодах

При BGP routing трафик может приходить на management интерфейс, но ответ идти через другой интерфейс (asymmetric routing). Linux по умолчанию дропает такие пакеты (strict reverse path filtering).

**Нужно установить на всех нодах:**
```yaml
# sysctl
net.ipv4.conf.all.rp_filter: 0
net.ipv4.conf.default.rp_filter: 0
net.ipv4.conf.br-management.rp_filter: 0
```

[Источник: AHdark Blog — root cause analysis](https://www.ahdark.blog/analyzing-load-balancer-vip-routing/)

### kube_proxy_strict_arp

Уже включён у тебя (`kube_proxy_strict_arp: true`). Это правильно — только нода с endpoint отвечает на ARP для service IP.

---

## 6. Сравнение подходов

### Подход A: Calico bird только (metallb_speaker_enabled: false)

```
Плюсы:
  ✓ Один BGP демон на ноде — меньше ресурсов, меньше точек отказа
  ✓ Одна BGP сессия к роутеру — нет конфликта сессий
  ✓ Единая точка управления всеми BGP маршрутами
  ✓ Kubespray нативно поддерживает через calico_advertise_service_loadbalancer_ips

Минусы:
  ✗ Calico анонсирует весь CIDR, не конкретные IP
  ✗ Требует ECMP на роутере для балансировки Cluster mode
  ✗ Требует rp_filter=0 на нодах
  ✗ Нет ARP ответов (но не проблема при L3 роутере между клиентами и нодами)
```

### Подход B: Calico bird + MetalLB speaker L2 mode

```
Плюсы:
  ✓ MetalLB speaker отвечает на ARP — работает даже без L3 роутера
  ✓ Calico bird делает BGP для маршрутизации
  ✓ Нет конфликта BGP сессий (speaker в L2, не BGP)

Минусы:
  ✗ Два демона на ноде
  ✗ L2 ARP ограничивает масштаб (ARP broadcast в одном L2 домене)
  ✗ Сложнее отлаживать (два компонента отвечают за разные вещи)
```

### Подход C: Calico bird + MetalLB speaker BGP mode (текущий)

```
Плюсы:
  ✓ MetalLB гибко настраивает announcement per pool

Минусы:
  ✗ ДВА BGP демона пытаются периться с одним роутером — КОНФЛИКТ
  ✗ Один из демонов будет отклонён (BGP позволяет одну сессию per pair)
  ✗ Требует обходных решений (VRF, разные роутеры, разные порты)
```

---

## 7. Рекомендация для твоей инфраструктуры

**Используй Подход A: Calico bird только.**

Обоснование:
1. У тебя центральный L3 роутер (`172.24.0.1`) между всеми VLAN — ARP не нужен
2. Роутер уже делает маршрутизацию между VLAN — public LB IP будут достижимы через management next-hop
3. Kubespray нативно поддерживает эту конфигурацию
4. Минимальная поверхность отказов — один BGP демон

### Что нужно изменить в group_vars/all.yaml:

```yaml
# MetalLB: только controller, без speaker
metallb_speaker_enabled: false

# Calico: анонсирует ВСЁ через один bird демон
calico_advertise_service_loadbalancer_ips:
  - 172.24.1.0/25
  - 172.24.1.128/25
  - 172.25.1.0/25
  - 172.25.1.128/25

# Убрать layer3 из metallb_config (без speaker — BGP config MetalLB не нужен)
# Оставить только address_pools
```

### Что нужно на роутере:
1. BGP peering с каждой нодой на `172.24.0.X` (AS 64512 ↔ AS 64513)
2. ECMP включён для BGP маршрутов (опционально, для Cluster mode)
3. Маршрутизация между management и public VLAN (обычно уже есть)

### Что нужно на нодах:
1. `rp_filter=0` (sysctl)
2. `kube_proxy_strict_arp: true` (уже есть)

---

## 8. Исходные материалы

### Официальная документация
- [Calico: Advertise Kubernetes service IP addresses](https://docs.tigera.io/calico/latest/networking/configuring/advertise-service-ips) — основной источник по serviceLoadBalancerIPs
- [Calico: BGPPeer reference (sourceAddress field)](https://docs.tigera.io/calico/latest/reference/resources/bgppeer) — sourceAddress: UseNodeIP/None
- [Calico: BGP peering configuration](https://docs.tigera.io/calico/latest/networking/configuring/bgp) — BGP топологии
- [MetalLB: Issues with Calico](https://metallb.universe.tf/configuration/calico/) — официальная интеграция MetalLB + Calico
- [Kubespray: MetalLB docs](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/ingress/metallb.md) — calico_advertise_service_loadbalancer_ips

### GitHub issues
- [Calico #5226: Support for multiple bgp peers with source address](https://github.com/projectcalico/calico/issues/5226) — multi-interface BGP, sourceAddress поле добавлено в v3.18
- [Kubespray #8974: Apply calico bgp peer definition task to all nodes](https://github.com/kubernetes-sigs/kubespray/pull/8974) — как kubespray применяет BGPPeer

### Блоги и статьи
- [AHdark: MetalLB with Calico BGP — Deployment, Architecture, and Validation](https://www.ahdark.blog/metallb-with-calico-bgp/) — production guide, controller-only + Calico BGP
- [AHdark: Analyzing Load Balancer VIP Routing with Calico BGP and MetalLB](https://www.ahdark.blog/analyzing-load-balancer-vip-routing/) — глубокий анализ проблем VIP binding, ARP, rp_filter
- [OneUptime: How to Configure MetalLB with Calico](https://oneuptime.com/blog/post/2026-01-07-metallb-calico-integration/view) — обзор интеграции
