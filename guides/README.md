⬅️ [Volver al README principal](../README.md)

# 🛠️ Guías Prácticas Multi-Vendor

Guías completas de configuración, verificación y mantenimiento diario. Cada guía parte del **protocolo estándar (IEEE / IETF)** y muestra cómo implementarlo y diagnosticarlo en **Cisco IOS**, **MikroTik RouterOS v7**, **Switches Gestionables (Aruba / Ubiquiti / TP-Link)** y **Linux (`iproute2` / `bridge` / `FRRouting`)**.

---

## 🗂️ Catálogo de guías por dominio

### 1. `01-fundamentals/` — Acceso, Descubrimiento y Diagnóstico Base

| Guía | Nivel | Qué enseña a configurar y operar |
|------|:-----:|----------------------------------|
| [`serial-console-and-oob-access.md`](01-fundamentals/serial-console-and-oob-access.md) | 🟢 Básico | Consola serie RJ45/USB (`9600` vs `115200 8N1`), acceso Out-of-Band (OOB) y rescate sin IP |
| [`ssh-hardening-and-management-plane.md`](01-fundamentals/ssh-hardening-and-management-plane.md) | 🟡 Intermedio | Claves SSH, VLAN de Management dedicada y cierre de servicios expuestos (Telnet/HTTP/WinBox en WAN) |
| [`neighbor-discovery-lldp-cdp-mndp.md`](01-fundamentals/neighbor-discovery-lldp-cdp-mndp.md) | 🟢 Básico | Descubrimiento y mapeo de topología en vivo usando LLDP (`802.1AB`), Cisco CDP y MikroTik MNDP |
| [`packet-capture-tcpdump-sniffer-epc.md`](01-fundamentals/packet-capture-tcpdump-sniffer-epc.md) | 🔴 Avanzado | Captura de paquetes en routers y switches: `/tool sniffer` (TZSP), Cisco EPC, Port Mirroring y `tcpdump` |

### 2. `02-switching-l2/` — Switching Capa 2 y Seguridad L2

| Guía | Nivel | Qué enseña a configurar y operar |
|------|:-----:|----------------------------------|
| `vlans-8021q-access-trunk-pvid.md` | 🟡 Intermedio | VLANs 802.1Q paso a paso: Access, Trunk, Hybrid y Native/PVID en Cisco, MikroTik Bridge VLAN Filtering, Aruba/TP-Link y Linux |
| `spanning-tree-rstp-bpduguard.md` | 🟡 Intermedio | RSTP (`802.1w`), elección determinista del Root Bridge, PortFast/Edge y bloqueo automático de bucles con BPDU Guard |
| `lacp-etherchannel-bonding.md` | 🟡 Intermedio | Agregación de enlaces `802.3ad LACP` (Cisco EtherChannel, MikroTik/Linux Bonding, Aruba Trunk) y balanceo por hash |
| `port-mirroring-span.md` | 🟢 Básico | Copia de tráfico de puertos o VLANs hacia analizadores Wireshark o sensores IDS |
| `l2-security-dhcp-snooping-dai-portsec.md` | 🔴 Avanzado | Protección contra Rogue DHCP (*DHCP Snooping*), ARP Spoofing (*DAI*) y límite de MACs por puerto |

### 3. `03-routing-l3/` — Enrutamiento, Inter-VLAN y Alta Disponibilidad

| Guía | Nivel | Qué enseña a configurar y operar |
|------|:-----:|----------------------------------|
| `inter-vlan-routing-roas-vs-svi.md` | 🟡 Intermedio | Enrutamiento entre VLANs: Router-on-a-Stick (subinterfaces) vs Switch Capa 3 (SVIs + L3 Hardware Offload) |
| `static-routing-and-floating-routes.md` | 🟢 Básico | Rutas estáticas, default gateway, rutas de descarte (blackhole/null0) y rutas flotantes de backup |
| `ospf-single-and-multi-area.md` | 🔴 Avanzado | OSPFv2 multi-vendor (Cisco ↔ MikroTik v7 ↔ FRRouting): áreas, Router-ID, interfaces pasivas, costos y troubleshooting |
| `vrrp-and-hsrp-gateway-redundancy.md` | 🟡 Intermedio | Redundancia de Default Gateway con VRRP y HSRP, preemption y seguimiento de enlaces WAN |
| `dual-wan-failover-and-load-balancing.md` | 🔴 Avanzado | Multi-WAN en producción: failover con rutas recursivas / IP SLA / Netwatch y balanceo PCC / PBR |

### 4. `04-firewalls-nat-vpn/` — Firewalls, NAT y VPNs

| Guía | Nivel | Qué enseña a configurar y operar |
|------|:-----:|----------------------------------|
| `stateful-firewall-and-zone-acls.md` | 🟡 Intermedio | Diseño de reglas `INPUT` y `FORWARD`, aislamiento entre zonas (LAN, DMZ, CCTV, Guest) y uso seguro de FastTrack |
| `nat-masquerade-dnat-and-hairpin.md` | 🟡 Intermedio | Source NAT / Masquerade, Port Forwarding (`DNAT`) y configuración de **Hairpin NAT** |
| `wireguard-site-to-site-and-roadwarrior.md` | 🟡 Intermedio | VPNs WireGuard entre sedes (MikroTik ↔ Linux) y acceso remoto de administradores con ajuste de MTU/MSS |
| `ipsec-ikev2-site-to-site.md` | 🔴 Avanzado | Túneles IPsec IKEv2 estándar entre fabricantes distintos (MikroTik ↔ Cisco / Fortinet / pfSense) y NAT Bypass |

### 5. `05-wireless-poe/` — WiFi Corporativo, PoE y Capa Física

| Guía | Nivel | Qué enseña a configurar y operar |
|------|:-----:|----------------------------------|
| `enterprise-wifi-vlans-and-roaming.md` | 🟡 Intermedio | Múltiples SSIDs con VLANs, planificación de canales 2.4/5GHz, potencia TX y roaming `802.11k/v/r` |
| `poe-budgeting-and-switch-management.md` | 🟢 Básico | Administración PoE `802.3af/at/bt`, prioridades de corte, monitoreo de watts y power-cycle remoto |
| `physical-diagnostics-sfp-fiber-and-tdr.md` | 🟡 Intermedio | Diagnóstico de cableado por TDR desde CLI, lectura de niveles ópticos SFP (`dBm`) y análisis de errores CRC |

### 6. `06-mikrotik/` — Especialización MikroTik RouterOS v7

| Guía | Nivel | Qué enseña a configurar y operar |
|------|:-----:|----------------------------------|
| `routeros-v7-first-setup-and-hardening.md` | 🟢 Básico | Configuración inicial limpia, hardening de servicios/MAC-Server, firewall base y RoMON |
| `mikrotik-bridge-vlan-filtering-deep-dive.md` | 🔴 Avanzado | Arquitectura del Switch Chip y `Bridge VLAN Filtering` con Hardware Offload (`H`) en CRS3xx/5xx y routers RB/CCR |
| `mikrotik-qos-simple-queues-and-queue-tree.md` | 🔴 Avanzado | Control de ancho de banda con Simple Queues, colas igualitarias PCQ y priorización con Mangle + Queue Tree |

### 7. `07-cisco/` — Especialización Cisco IOS / Catalyst

| Guía | Nivel | Qué enseña a configurar y operar |
|------|:-----:|----------------------------------|
| `cisco-ios-cli-architecture-and-hardening.md` | 🟢 Básico | Arquitectura CLI, seguridad VTY/SSH, `errdisable recovery` automático y archivo de configuraciones |
| `cisco-rommon-password-recovery-and-ios-upgrade.md` | 🟡 Intermedio | Recuperación de acceso por ROMMON (`0x2142`), actualización y verificación de imágenes IOS |

### 8. `08-operations/` — Mantenimiento y Operación del Día a Día

| Guía | Nivel | Qué enseña a configurar y operar |
|------|:-----:|----------------------------------|
| [`network-backups-export-and-git-versioning.md`](08-operations/network-backups-export-and-git-versioning.md) | 🟢 Básico | Backups en texto plano (`.rsc` / `running-config`) vs binarios, automatización por SSH/Oxidized y control en Git |
| [`firmware-upgrades-and-maintenance-windows.md`](08-operations/firmware-upgrades-and-maintenance-windows.md) | 🟡 Intermedio | Protocolo seguro de actualización de RouterOS + RouterBOOT, Cisco IOS y switches sin dejar sedes aisladas |
| [`snmp-syslog-and-netflow-monitoring.md`](08-operations/snmp-syslog-and-netflow-monitoring.md) | 🟡 Intermedio | Observabilidad diaria con SNMPv2c/v3, Syslog centralizado y análisis de tráfico con NetFlow / Traffic Flow |

---

⬅️ [Volver al README principal](../README.md)
