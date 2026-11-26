# 🌐 learning-network-guides

[![Validate Markdown](https://github.com/lumusitech/learning-network-guides/actions/workflows/validate.yml/badge.svg?branch=main)](https://github.com/lumusitech/learning-network-guides/actions/workflows/validate.yml)

Sistema de aprendizaje práctico para **ingeniería, administración y operación de redes (NetOps)**: desde los fundamentos de capa física, modelos **OSI y TCP/IP**, hasta configuraciones multi-vendor (**Cisco IOS, MikroTik RouterOS v7, Aruba/HP, Ubiquiti, switches gestionables y Linux**), mantenimiento preventivo y resolución de incidentes reales del día a día.

> **Frase guía:**
> No coleccionamos comandos sueltos por marca. Construimos un modelo mental de protocolos estándar (IEEE / IETF) y aprendemos cómo implementarlos, mantenerlos y diagnosticarlos en cualquier fabricante.

---

## 📊 En números

| Categoría | Cantidad |
|-----------|:--------:|
| 🧠 [Conceptos y Modelos Mentales](concepts/) | **14** |
| 🛠️ [Guías Prácticas Multi-Vendor](guides/) | **24** |
| 🚨 [Escenarios Reales y Runbooks](scenarios/) | **20** |
| 📚 [Referencias Rápidas y Cheatsheets](reference/) | **7** |
| 🧪 [Entornos de Laboratorio Docker / FRR](labs/) | **4** |

---

## 🎯 Filosofía del proyecto

1. **Estándar primero, fabricante después:** Primero entendés cómo funciona el protocolo (`802.1Q`, `802.1w RSTP`, `802.3ad LACP`, `OSPF`, `VRRP`, `NAT/Conntrack`, `WireGuard`, `IPsec IKEv2`) y luego ves su traducción exacta en **Cisco IOS**, **MikroTik RouterOS v7**, **Aruba / Ubiquiti / TP-Link Omada** y **Linux (`iproute2` / `bridge` / `FRRouting`)**.
2. **De cero a operación real:** Progresión completa desde el cable de cobre, la fibra óptica (`dBm`), la trama Ethernet y el subnetting CIDR/VLSM, hasta el mantenimiento del día a día (backups `.rsc` en Git, upgrades de firmware `RouterOS + RouterBOOT` sin corte, monitoreo SNMPv3/Syslog/NetFlow y respuesta a guardias).
3. **Práctica reproducible:** Topologías de laboratorio ejecutables con **Docker Compose + FRRouting (`vtysh` estilo Cisco IOS) + Linux Bridge VLAN-aware + Conntrack** en [`labs/`](labs/) para practicar sin depender de hardware físico.
4. **Cada salida interpretada:** No solo mostramos qué comando correr (`show interfaces trunk`, `/interface bridge vlan print`), sino qué significa cada columna, cada flag (`R`, `S`, `H`, `D`, `A`, `P`, `I`, `err-disabled`) y cómo se ve cuando algo está roto.

---

## 📁 Estructura del repositorio

```text
.
├── concepts/          # 14 modelos mentales (OSI, TCP/IP, Capa 1, Ethernet/ARP, VLANs, RSTP, LACP, CIDR, Routing, VRRP, MTU/NAT, Firewalls, DHCP/DNS/NTP, NetOps)
├── guides/            # 24 guías de configuración y operación multi-vendor divididas en 8 dominios
│   ├── 01-fundamentals/     # Consola serie/OOB, SSH hardening, LLDP/CDP/MNDP, captura (tcpdump/sniffer/EPC)
│   ├── 02-switching-l2/     # VLANs (802.1Q), RSTP + BPDU Guard, LACP (802.3ad), Port Mirroring (SPAN), DHCP Snooping/DAI
│   ├── 03-routing-l3/       # Inter-VLAN (ROAS vs SVI), Rutas estáticas/flotantes, OSPFv2, VRRP/HSRP, Dual-WAN Recursivo/PCC
│   ├── 04-firewalls-nat-vpn/# Firewall Stateful por Zonas, NAT/DNAT/Hairpin NAT, WireGuard, IPsec IKEv2 Site-to-Site
│   ├── 05-wireless-poe/     # WiFi Corporativo (canales y roaming 802.11k/v/r), PoE Budget/Watchdog, TDR y Fibra SFP (dBm)
│   ├── 06-mikrotik/         # Especialización RouterOS v7: Setup limpio + Puerto Rescate, Bridge VLAN Filtering (H), QoS/PCQ/fq-codel
│   ├── 07-cisco/            # Especialización Cisco IOS: Arquitectura CLI/Hardening, Recuperación ROMMON (0x2142) e imágenes IOS
│   └── 08-operations/       # Día a día: Backups .rsc en Git, Upgrades de Firmware en 4 fases, Monitoreo SNMPv3/Syslog/NetFlow
├── labs/              # 4 laboratorios Docker Compose + FRRouting para practicar VLANs, STP, OSPF (ExStart) y Hairpin NAT
├── scenarios/         # 20 incidentes y ventanas de mantenimiento reales resueltos paso a paso
│   ├── l1-l2/               # Par cortado a 100Mbps (TDR), Tormenta STP, Native VLAN Mismatch, PoE nocturno, LACP roto, Fibra LOS
│   ├── l3-routing/          # Blackhole de MTU/MSS en PPPoE/VPN, Ruta asimétrica (INVALID), OSPF ExStart, ISP Zombie, VRRP Split-Brain
│   ├── security-vpn/        # Rogue DHCP en LAN, Hairpin NAT interno, VPN UP pero sin tráfico por NAT, Router expuesto a fuerza bruta
│   ├── wireless/            # Sticky Clients pegados a AP lejano, Celular en "Obteniendo IP..." (169.254.x.x) en VLAN de SSID
│   └── maintenance/         # Migración de red plana a VLANs sin corte, Reemplazo de Switch Core multi-vendor, Upgrade remoto a 250 km
└── reference/         # 7 cheatsheets de campo (Piedra Rosetta CLI, CIDR/VLSM/CGNAT, Fibra/SFP/PoE, IEEE/RFC, Puertos/Multicast, Matriz de Guardia, Active Recall)
```

**Flujo pedagógico:**

```text
concepts → guides → labs → scenarios ↔ reference
entender → configurar → practicar → diagnosticar y mantener
```

---

## 🗺️ Roadmap de aprendizaje (De OSI al día a día)

### Nivel 1 — Fundamentos y Modelos Mentales ([`concepts/`](concepts/))

1. **Modelos OSI y TCP/IP en la vida real:** [`how-to-think-like-network-engineer.md`](concepts/how-to-think-like-network-engineer.md) y [`osi-and-tcp-ip-models.md`](concepts/osi-and-tcp-ip-models.md).
2. **Capa 1 (Física):** [`physical-layer-cables-fiber-poe.md`](concepts/physical-layer-cables-fiber-poe.md) — Cobre (4 pares T568B), fibra óptica (OS2 vs OM3/OM4, SFP `dBm`), duplex y PoE (`802.3af/at/bt` vs pasivo).
3. **Capa 2 (Switching y Segmentación):** [`ethernet-mac-and-arp.md`](concepts/ethernet-mac-and-arp.md), [`vlans-tagged-untagged-and-trunks.md`](concepts/vlans-tagged-untagged-and-trunks.md), [`spanning-tree-and-loop-prevention.md`](concepts/spanning-tree-and-loop-prevention.md) y [`link-aggregation-and-redundancy-l2.md`](concepts/link-aggregation-and-redundancy-l2.md).
4. **Capa 3 (Direccionamiento y Routing):** [`ipv4-addressing-subnetting-and-vlsm.md`](concepts/ipv4-addressing-subnetting-and-vlsm.md), [`routing-fundamentals-static-and-dynamic.md`](concepts/routing-fundamentals-static-and-dynamic.md) y [`first-hop-redundancy-vrrp-hsrp.md`](concepts/first-hop-redundancy-vrrp-hsrp.md).
5. **Capas 4 a 7 y Día a Día NetOps:** [`tcp-udp-mtu-and-nat-conntrack.md`](concepts/tcp-udp-mtu-and-nat-conntrack.md), [`stateful-firewalls-and-zone-segmentation.md`](concepts/stateful-firewalls-and-zone-segmentation.md), [`dhcp-dns-and-network-services.md`](concepts/dhcp-dns-and-network-services.md) y [`netops-day-to-day-maintenance-and-observability.md`](concepts/netops-day-to-day-maintenance-and-observability.md).

### Nivel 2 — Switching L2/L3 Multi-Vendor ([`guides/02-switching-l2/`](guides/README.md) & [`06-mikrotik/`](guides/README.md))

1. **Primer contacto con equipos:** acceso por cable de consola (RS-232/USB), SSH hardening, gestión Out-of-Band (OOB) y descubrimiento LLDP/CDP/MNDP.
2. **VLANs y Trunking (`IEEE 802.1Q`):** puertos Access, Trunk y Hybrid; Native VLAN / PVID en Cisco vs MikroTik Bridge VLAN Filtering (`H`) vs Aruba/Ubiquiti/TP-Link.
3. **Prevención de bucles y Agregación:** RSTP (`802.1w`), Root Bridge (`4096`), `PortFast/Edge`, `BPDU Guard` y LACP (`802.3ad`).
4. **Seguridad y Monitoreo en Capa 2:** `DHCP Snooping`, `Dynamic ARP Inspection (DAI)`, `Port Security` y `Port Mirroring (SPAN)`.

### Nivel 3 — Routing, Firewalls y Conectividad ([`guides/03-routing-l3/`](guides/README.md) & [`04-firewalls-nat-vpn/`](guides/README.md))

1. **Inter-VLAN Routing:** Router-on-a-Stick (ROAS) vs Switch Capa 3 (SVIs / L3 Hardware Offloading).
2. **Enrutamiento Estático y Dinámico:** rutas flotantes, blackholes anti-fuga y OSPFv2 multi-vendor (Cisco ↔ MikroTik v7 ↔ FRRouting).
3. **Redundancia de Gateway y Multi-WAN:** VRRP / HSRP con *WAN Tracking*, failover automático con Rutas Recursivas (`scope/target-scope`) y balanceo PCC.
4. **Firewalls, NAT y VPNs:** cadenas `INPUT` vs `FORWARD`, segmentación por zonas, Destination NAT, Hairpin NAT, **WireGuard** e **IPsec IKEv2**.

### Nivel 4 — Operación, Mantenimiento y Guardias ([`guides/08-operations/`](guides/README.md) & [`scenarios/`](scenarios/README.md))

1. **Backups y Control de Cambios:** exportación automática en texto plano (`.rsc` / `running-config`) versionada en **Git** y rollback atómico (`configure replace`).
2. **Actualizaciones de Firmware Seguras:** runbook de 4 fases para `RouterOS + RouterBOOT`, Cisco IOS y switches con doble partición.
3. **Observabilidad y Runbooks de Guardia:** SNMPv3 (`ifHCInOctets`), Syslog centralizado, NetFlow/IPFIX y resolución paso a paso de los 20 incidentes más frecuentes en producción.

---

## 🔄 Equivalencia Multi-Vendor (Piedra Rosetta del repositorio)

Cada guía práctica muestra cómo traducir la misma tarea entre ecosistemas (ver tabla completa en [`reference/multivendor-cli-rosetta-stone.md`](reference/multivendor-cli-rosetta-stone.md)):

| Tarea | Cisco IOS | MikroTik RouterOS v7 | Linux (`iproute2` / `bridge` / `FRR`) |
|-------|-----------|----------------------|---------------------------------------|
| Ver interfaces y estado | `show ip interface brief` | `/interface print` | `ip -br link` / `ip -br addr` |
| Ver tabla MAC | `show mac address-table` | `/interface bridge host print` | `bridge fdb show` |
| Ver VLANs en trunks | `show interfaces trunk` | `/interface bridge vlan print` | `bridge vlan show` |
| Ver tabla de rutas | `show ip route` | `/ip route print` | `ip route show` |
| Ver vecinos (LLDP/CDP) | `show cdp/lldp neighbors` | `/ip neighbor print` | `lldpcli show neighbors` |

---

## 🔗 Repositorio hermano

- 🐧 [`learning-sys-admin-guides`](https://github.com/lumusitech/learning-sys-admin-guides) — Administración de servidores Linux, herramientas POSIX, contenedores y SRE.

---

## ✅ Licencia

MIT
