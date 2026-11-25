# 🌐 learning-network-guides

Sistema de aprendizaje práctico para **ingeniería, administración y operación de redes (NetOps)**: desde los fundamentos de capa física, modelos **OSI y TCP/IP**, hasta configuraciones multi-vendor (**Cisco, MikroTik, Aruba/HP, Ubiquiti, switches genéricos y Linux**), mantenimiento preventivo y resolución de incidentes reales del día a día.

> **Frase guía:**
> No coleccionamos comandos sueltos por marca. Construimos un modelo mental de protocolos estándar (IEEE / IETF) y aprendemos cómo implementarlos, mantenerlos y diagnosticarlos en cualquier fabricante.

---

## 🎯 Filosofía del proyecto

1. **Estándar primero, fabricante después:** Primero entendés cómo funciona el protocolo (`802.1Q`, `802.1w RSTP`, `802.3ad LACP`, `OSPF`, `BGP`, `NAT`, `WireGuard`, `802.1X`) y luego ves su traducción exacta en **Cisco IOS**, **MikroTik RouterOS**, **Ubiquiti / Aruba / TP-Link Omada** y **Linux (`iproute2` / `FRRouting`)**.
2. **De cero a operación real:** Progresión completa desde el cable, la trama Ethernet y el subnetting, hasta el mantenimiento del día a día (backups de configuración, upgrades de firmware sin corte, monitoreo SNMP/NetFlow, auditoría de cambios y respuesta a caídas).
3. **Práctica reproducible:** Topologías de laboratorio reproducibles con contenedores y simuladores (**Containerlab**, **FRRouting**, **Open vSwitch**, **MikroTik CHR**, **Docker**) para practicar sin depender de hardware físico.
4. **Cada salida interpretada:** No solo mostramos qué comando correr (`show interfaces trunk`, `/interface bridge vlan print`), sino qué significa cada columna, cada flag y cómo se ve cuando algo está roto.

---

## 📁 Estructura del repositorio

```text
.
├── concepts/          # Modelos mentales y fundamentos (OSI, TCP/IP, direccionamiento, ARP, switching, routing)
├── guides/            # Guías de configuración y operación por tecnología y fabricante
│   ├── fundamentals/  # Herramientas base, consola serie, SSH, SNMP, captura de paquetes
│   ├── switching/     # VLANs (802.1Q), Trunks, STP/RSTP, LACP, Port Security, DHCP Snooping, SPAN
│   ├── routing/       # Rutas estáticas, Inter-VLAN, OSPF, BGP, PBR, Dual-WAN / Failover
│   ├── firewalls-vpn/ # ACLs, Firewall Stateful, NAT/PAT, WireGuard, IPsec, OpenVPN
│   ├── wireless-poe/  # WiFi corporativo, roaming, RADIUS, PoE budget, diagnóstico físico/cableado
│   ├── mikrotik/      # RouterOS & SwOS: Bridge VLAN filtering, Mangle, Queues/QoS, PCC, Netwatch
│   ├── cisco/         # Cisco IOS / Catalyst: CLI, VLANs, EtherChannel, HSRP/VRRP, hardening
│   └── operations/    # Día a día: backups, actualización de firmware, syslog, SNMP, checklists
├── labs/              # Topologías prácticas reproducibles (Containerlab / Docker / FRR / OVS)
├── scenarios/         # Incidentes y tareas reales resueltas paso a paso (runbooks)
│   ├── l1-l2/         # Loops de capa 2, native VLAN mismatch, flapping, PoE, errores CRC/duplex
│   ├── l3-routing/    # Rutas asimétricas, blackholes, MTU/MSS, caída de vecino OSPF, Dual-WAN
│   ├── security-vpn/  # Rogue DHCP, ARP spoofing, túneles VPN caídos, bloqueo por firewall
│   ├── wireless/      # Interferencia de canales, roaming fallido, saturación de clientes
│   └── maintenance/   # Ventanas de mantenimiento, migración de switch core, upgrade de RouterOS/IOS
└── reference/         # Tablas comparativas multi-vendor, subredes CIDR, puertos, cableado y estándares IEEE
```

**Flujo pedagógico:**

```text
concepts → guides → labs → scenarios
entender → configurar → practicar → operar y diagnosticar
```

---

## 🗺️ Roadmap de aprendizaje (De OSI al día a día)

### Nivel 1 — Fundamentos y Modelos Mentales (`concepts/`)

1. **Modelos OSI y TCP/IP en la vida real:** encapsulamiento, PDUs (bits, tramas, paquetes, segmentos) y cómo usar las capas para aislar cualquier falla en 2 minutos.
2. **Capa 1 (Física):** cobre (Cat5e/6/6A), fibra óptica (monomodo vs multimodo, transceptores SFP/SFP+), PoE (802.3af/at/bt), negociación de velocidad/duplex y diagnóstico de errores físicos (CRC, runts, giants).
3. **Capa 2 (Enlace de datos):** direcciones MAC, tablas CAM/FDB, ARP, dominios de colisión vs dominios de difusión (broadcast).
4. **Capa 3 (Red) y Direccionamiento:** IPv4 a fondo, subnetting CIDR/VLSM sin dolor, IPv6 esencial, ICMP, tablas de enrutamiento y longest-prefix match.
5. **Capa 4 (Transporte) y Servicios Esenciales:** TCP (3-way handshake, flags, ventanas, MSS) vs UDP, puertos, DNS, DHCP (DORA + Relay) y NAT/PAT.

### Nivel 2 — Switching L2/L3 Multi-Vendor (`guides/switching/`)

1. **Primer contacto con equipos:** acceso por cable de consola (RS-232/USB), SSH, hardening inicial, gestión out-of-band (OOB).
2. **VLANs y Trunking (IEEE 802.1Q):** puertos Access, Trunk y Hybrid; Native VLAN / PVID (cómo funcionan en Cisco vs MikroTik Bridge VLAN Filtering vs Ubiquiti/TP-Link).
3. **Prevención de bucles (STP / RSTP / MSTP):** elección de Root Bridge, PortFast / Edge Port, BPDU Guard y qué pasa cuando alguien conecta un cable entre dos bocas de pared.
4. **Agregación de enlaces (LACP / 802.3ad):** EtherChannel en Cisco, Bonding en MikroTik y Linux.
5. **Seguridad en Capa 2:** DHCP Snooping, Dynamic ARP Inspection (DAI), Port Security, aislamiento de puertos y 802.1X.

### Nivel 3 — Routing, Firewalls y Conectividad (`guides/routing/` & `guides/firewalls-vpn/`)

1. **Inter-VLAN Routing:** Router-on-a-Stick vs Switch Capa 3 (SVIs).
2. **Enrutamiento Estático y Dinámico:** rutas flotantes, OSPF (single-area y multi-area), introducción práctica a BGP e integración con FRRouting.
3. **Redundancia de Gateway y Multi-WAN:** VRRP / HSRP, failover automático de proveedores de Internet (ISP) con chequeo de salud y balanceo de carga (PCC en MikroTik / PBR).
4. **Firewalls y NAT:** tablas y cadenas (Input/Forward/Output), Stateful Inspection, Destination NAT (Port Forwarding), Hairpin NAT y segmentación por zonas (LAN, DMZ, IoT, CCTV, Invitados).
5. **VPNs Site-to-Site y Remote Access:** WireGuard, IPsec IKEv2 y diseño de acceso remoto seguro para administradores.

### Nivel 4 — Operación y Mantenimiento del Día a Día (`guides/operations/` & `scenarios/maintenance/`)

1. **Backups y Control de Cambios:** exportación automática de configuraciones (`.rsc` en MikroTik, `running-config` en Cisco), control de versiones en Git y detección de *config drift*.
2. **Actualizaciones de Firmware Seguras:** procedimientos pre-check, upgrade y rollback en switches, routers y controladoras WiFi sin dejar aislada la sede.
3. **Observabilidad de Red:** SNMP (v2c/v3), Syslog centralizado, NetFlow/sFlow, LLDP/CDP/MNDP para descubrir y documentar la topología real.
4. **Runbooks de guardia:** qué hacer ante tormentas de broadcast, caídas de fibra, agotamiento de pools DHCP, conflictos de IP o saturación de ancho de banda.

---

## 🔄 Equivalencia Multi-Vendor (enfoque del repositorio)

Cada guía práctica muestra cómo traducir la misma tarea entre ecosistemas:

| Tarea | Cisco IOS | MikroTik RouterOS | Linux (`iproute2` / `bridge`) |
|-------|-----------|-------------------|-------------------------------|
| Ver interfaces y estado | `show ip interface brief` | `/interface print` | `ip -br link` / `ip -br addr` |
| Ver tabla MAC | `show mac address-table` | `/interface bridge host print` | `bridge fdb show` |
| Ver VLANs en trunks | `show interfaces trunk` | `/interface bridge vlan print` | `bridge vlan show` |
| Ver tabla de rutas | `show ip route` | `/ip route print` | `ip route show` |
| Ver vecinos (LLDP/CDP) | `show cdp neighbors detail` / `show lldp neighbors` | `/ip neighbor print` | `lldpcli show neighbors` |

---

## 🔗 Repositorio hermano

- 🐧 [`learning-sys-admin-guides`](https://github.com/lumusitech/learning-sys-admin-guides) — Administración de servidores Linux, herramientas POSIX, contenedores y SRE.

---

## ✅ Licencia

MIT
