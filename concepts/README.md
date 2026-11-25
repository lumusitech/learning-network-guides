⬅️ [Volver al README principal](../README.md)

# 🧠 Conceptos y Modelos Mentales de Redes

Esta sección construye el **modelo mental** de un ingeniero y administrador de redes antes de tocar cualquier consola CLI o interfaz web.

> **Regla de oro:** Los fabricantes cambian los nombres de los menús y la sintaxis de los comandos, pero los protocolos **IEEE / IETF** y las leyes de las capas **OSI / TCP-IP** son siempre los mismos. Si entendés cómo viaja la trama y cómo piensa el protocolo, podés configurar y diagnosticar cualquier marca.

---

## 🎯 Cuándo usar esta sección

Leé `concepts/` cuando:

- querés entender **cómo funciona un protocolo por dentro** antes de configurarlo
- necesitás traducir un concepto entre **Cisco, MikroTik, Aruba/Ubiquiti/TP-Link y Linux**
- querés saber **qué señales son normales y cuáles indican una falla** en cada capa
- estás diseñando una topología o buscando la causa raíz de un incidente complejo

---

## 🗺️ Índice progresivo de conceptos (De Capa 1 al Día a Día — 14/14 Completados)

### Bloque 1 — Fundamentos y Modelos de Diagnóstico

| # | Concepto | Capas | Qué vas a dominar |
|---|----------|:-----:|-------------------|
| 1 | [`how-to-think-like-network-engineer.md`](how-to-think-like-network-engineer.md) | 1–7 | Diagnóstico sistemático por capas, plano de control vs datos vs gestión, baseline y cambios seguros |
| 2 | [`osi-and-tcp-ip-models.md`](osi-and-tcp-ip-models.md) | 1–7 | Encapsulamiento byte a byte, cabeceras, PDUs (bits, tramas, paquetes, segmentos) y aislamiento de fallas |
| 3 | [`physical-layer-cables-fiber-poe.md`](physical-layer-cables-fiber-poe.md) | 1 | Cobre (Cat5e/6/6A), fibra óptica (OS2 vs OM3/OM4, SFP/SFP+, dBm), duplex/velocidad y PoE (802.3af/at/bt vs pasivo) |

### Bloque 2 — Capa 2: Switching, Ethernet y Segmentación

| # | Concepto | Capas | Qué vas a dominar |
|---|----------|:-----:|-------------------|
| 4 | [`ethernet-mac-and-arp.md`](ethernet-mac-and-arp.md) | 2 | Trama Ethernet, tabla MAC/CAM del switch (Learning/Flooding/Forwarding), dominios de broadcast y ARP |
| 5 | [`vlans-tagged-untagged-and-trunks.md`](vlans-tagged-untagged-and-trunks.md) | 2 | Estándar 802.1Q, PVID/Ingress vs Egress y equivalencia exacta: `Access/Trunk` (Cisco) ↔ `Untagged/Tagged/PVID` (MikroTik/Aruba/Genéricos) |
| 6 | [`spanning-tree-and-loop-prevention.md`](spanning-tree-and-loop-prevention.md) | 2 | Por qué un loop L2 tira toda la red, cómo eligen Root Bridge STP/RSTP, PortFast/Edge y BPDU Guard |
| 7 | [`link-aggregation-and-redundancy-l2.md`](link-aggregation-and-redundancy-l2.md) | 2 | LACP (802.3ad), algoritmos de hash y por qué EtherChannel/Bonding multiplica caudal total pero no el de un solo flujo TCP |

### Bloque 3 — Capa 3: Direccionamiento, Enrutamiento y Redundancia

| # | Concepto | Capas | Qué vas a dominar |
|---|----------|:-----:|-------------------|
| 8 | [`ipv4-addressing-subnetting-and-vlsm.md`](ipv4-addressing-subnetting-and-vlsm.md) | 3 | CIDR, cálculo rápido de subredes, RFC 1918, CGNAT (`100.64.0.0/10`), enlaces `/30` y `/31` y diseño de direccionamiento por sede/VLAN |
| 9 | [`routing-fundamentals-static-and-dynamic.md`](routing-fundamentals-static-and-dynamic.md) | 3 | Qué cambia en cada salto (MAC vs IP/TTL), tabla de rutas, *Longest Prefix Match*, Distancia Administrativa multi-vendor, Inter-VLAN (ROAS vs SVI), OSPF y BGP |
| 10 | [`first-hop-redundancy-vrrp-hsrp.md`](first-hop-redundancy-vrrp-hsrp.md) | 3 | Redundancia de Default Gateway con VRRP y HSRP, IP/MAC virtual, Master/Backup y tracking de caída de WAN |

### Bloque 4 — Capas 4 a 7: Transporte, NAT, Firewalls, Servicios y Operación

| # | Concepto | Capas | Qué vas a dominar |
|---|----------|:-----:|-------------------|
| 11 | [`tcp-udp-mtu-and-nat-conntrack.md`](tcp-udp-mtu-and-nat-conntrack.md) | 3–4 | Handshake TCP, MTU vs MSS (PPPoE/VPNs y MSS Clamping), tabla Conntrack y los 4 tipos de NAT (SNAT/Masquerade, DNAT, 1:1, Hairpin NAT) |
| 12 | [`stateful-firewalls-and-zone-segmentation.md`](stateful-firewalls-and-zone-segmentation.md) | 3–7 | ACL stateless vs Firewall stateful, flujo de cadenas (`INPUT` vs `FORWARD` vs `OUTPUT`) y arquitectura de zonas (LAN, DMZ, CCTV/IoT, Guest) |
| 13 | [`dhcp-dns-and-network-services.md`](dhcp-dns-and-network-services.md) | 2–7 | Ciclo DHCP DORA, DHCP Relay (`ip helper-address`), Rogue DHCP, resolución DNS (Split-Horizon) y por qué NTP es crítico |
| 14 | [`netops-day-to-day-maintenance-and-observability.md`](netops-day-to-day-maintenance-and-observability.md) | 1–7 | Operación diaria: SNMP, Syslog, NetFlow, descubrimiento LLDP/CDP/MNDP, backups en texto (`.rsc`/`running-config`) y ventanas de mantenimiento sin corte |

---

⬅️ [Volver al README principal](../README.md)
