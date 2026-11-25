# Catálogo y Estándares para `guides/`

Todo modelo que cree o edite una guía en `guides/` debe respetar la ubicación por carpeta de dominio, el nombre de archivo en `kebab-case.md` y cubrir los subtemas obligatorios.

---

## Estructura de dominios en `guides/`

### `guides/01-fundamentals/` — Acceso, Descubrimiento y Diagnóstico Base

| Archivo | Subtemas obligatorios |
|---------|-----------------------|
| `serial-console-and-oob-access.md` | Cable consola RJ45/DB9/USB-FTDI, parámetros `9600 8N1` (Cisco) vs `115200 8N1` (MikroTik/Aruba), uso de `minicom`/`screen`/`tio`, acceso Out-of-Band (OOB) y recuperación cuando se pierde IP. |
| `ssh-hardening-and-management-plane.md` | Claves SSH Ed25519/RSA en Cisco IOS, MikroTik RouterOS y switches; deshabilitar Telnet/HTTP/FTP/WinBox en WAN; restringir acceso por VLAN de Management e IP permitidas. |
| `neighbor-discovery-lldp-cdp-mndp.md` | Cómo mapear una red sin documentación usando LLDP (`802.1AB`), Cisco CDP y MikroTik MNDP; cómo activar/desactivar anuncios en puertos WAN por seguridad. |
| `packet-capture-tcpdump-sniffer-epc.md` | Captura de tráfico en vivo: `/tool sniffer` en MikroTik (con streaming TZSP a Wireshark), Embedded Packet Capture (EPC) en Cisco, Port Mirroring y `tcpdump -ni eth0 -e` con filtros VLAN. |

### `guides/02-switching-l2/` — Switching Capa 2 y Seguridad L2

| Archivo | Subtemas obligatorios |
|---------|-----------------------|
| `vlans-8021q-access-trunk-pvid.md` | Creación de VLANs, puertos Access (`untagged` + `PVID`), puertos Trunk (`tagged`) y puertos Híbridos (VoIP + PC); Cisco IOS vs MikroTik Bridge VLAN Filtering (`vlan-filtering=yes`, `frame-types`) vs Aruba/TP-Link/Ubiquiti vs Linux bridge. |
| `spanning-tree-rstp-bpduguard.md` | Configuración de RSTP (`802.1w`), cómo forzar el Root Bridge primario y secundario (`priority 4096 / 0x1000`), activación de `PortFast` / `edge=yes` y protección contra bucles con `BPDU Guard` / `Loop Protect`. |
| `lacp-etherchannel-bonding.md` | Agregación de enlaces `802.3ad LACP`: `channel-group mode active` en Cisco, `/interface bonding mode=802.3ad` en MikroTik, `Trunk LACP` en Aruba/TP-Link y `bonding` en Linux; transporte de VLANs sobre el LAG. |
| `port-mirroring-span.md` | Configuración de SPAN / Port Mirroring para enviar copia del tráfico de un puerto o VLAN hacia un analizador Wireshark/IDS en Cisco, MikroTik (`mirror-source`/`mirror-target`) y switches web. |
| `l2-security-dhcp-snooping-dai-portsec.md` | Bloqueo de servidores DHCP piratas con **DHCP Snooping** (puertos `trusted` vs `untrusted`), Dynamic ARP Inspection (DAI) y límite de MACs por puerto (*Port Security*). |

### `guides/03-routing-l3/` — Enrutamiento, Inter-VLAN y Redundancia

| Archivo | Subtemas obligatorios |
|---------|-----------------------|
| `inter-vlan-routing-roas-vs-svi.md` | Router-on-a-Stick (subinterfaces `Gi0/0.10` en Cisco, `/interface vlan` en MikroTik/Linux) vs Switch Capa 3 con interfaces `Vlan10` (SVI) y `ip routing` / L3 Hardware Offloading. |
| `static-routing-and-floating-routes.md` | Rutas estáticas, default gateway, rutas de resumen, rutas blackhole/null0 para evitar bucles y rutas flotantes con distancia administrativa mayor para backup. |
| `ospf-single-and-multi-area.md` | Configuración práctica de **OSPFv2**: Router-ID, áreas (`Area 0` backbone), interfaces pasivas (`passive-interface default`), costo por ancho de banda, autenticación y diagnóstico de estados (`Init`, `2-Way`, `ExStart`, `Full`) en Cisco, MikroTik v7 y FRRouting. |
| `vrrp-and-hsrp-gateway-redundancy.md` | Alta disponibilidad de Default Gateway entre dos routers: VRRP en MikroTik/Linux/Aruba y HSRP en Cisco; prioridades, preemption y tracking de caída de WAN. |
| `dual-wan-failover-and-load-balancing.md` | Configuración real de 2 proveedores de Internet: failover con chequeo recursivo de rutas (*recursive routing* / IP SLA / Netwatch) y balanceo PCC (*Per Connection Classifier*) o PBR sin romper bancos ni HTTPS. |

### `guides/04-firewalls-nat-vpn/` — Firewalls, NAT y VPNs

| Archivo | Subtemas obligatorios |
|---------|-----------------------|
| `stateful-firewall-and-zone-acls.md` | Diseño de reglas limpias en `INPUT` (proteger al router) y `FORWARD` (aislar VLANs Corporativa, Servidores, CCTV/IoT e Invitados); FastTrack, reglas `established,related`, `drop invalid` y bloqueo por listas de direcciones (`address-list` / `ipset`). |
| `nat-masquerade-dnat-and-hairpin.md` | Source NAT (`masquerade` vs `src-nat` con IP fija), Destination NAT (Port Forwarding hacia servidores internos) y solución definitiva al **Hairpin NAT** (entrar al servidor local desde la propia LAN usando el dominio público). |
| `wireguard-site-to-site-and-roadwarrior.md` | VPN moderna con **WireGuard** entre sedes (MikroTik ↔ Linux ↔ clientes remotos): generación de claves, `AllowedIPs`, rutas estáticas sobre el túnel y ajuste de MTU/MSS (`1420` / `1380`). |
| `ipsec-ikev2-site-to-site.md` | Túneles IPsec IKEv2 estándar entre fabricantes distintos (ej. MikroTik ↔ Cisco / Fortinet / pfSense): Fase 1 (Proposals/Profiles), Fase 2 (Policies/Traffic Selectors) y exención de NAT (*NAT Bypass*). |

### `guides/05-wireless-poe/` — WiFi Corporativo, PoE y Capa Física

| Archivo | Subtemas obligatorios |
|---------|-----------------------|
| `enterprise-wifi-vlans-and-roaming.md` | Mapeo de múltiples SSIDs a VLANs (`802.1Q`), selección de canales sin solapamiento (`1, 6, 11` en 2.4GHz; canales UNII/DFS en 5GHz), ancho de canal (`20MHz` vs `40/80MHz`), potencia TX y roaming `802.11k/v/r` en UniFi, Aruba, Cisco y MikroTik CAPsMAN/WiFiWave2. |
| `poe-budgeting-and-switch-management.md` | Gestión de PoE `802.3af/at/bt` en switches Cisco (`show power inline`), MikroTik (`/interface ethernet poe`), Ubiquiti y Aruba: prioridades por puerto, power-cycle remoto de cámaras/APs colgados y cálculo de presupuesto en watts. |
| `physical-diagnostics-sfp-fiber-and-tdr.md` | Diagnóstico de capa 1 desde CLI: test de cable TDR integrado (`test cable-diagnostics tdr` en Cisco, `/interface ethernet cable-test` en MikroTik), lectura de niveles ópticos SFP (`Tx/Rx Power dBm`, temperatura) y contadores CRC/FCS. |

### `guides/06-mikrotik/` — Especialización MikroTik RouterOS v7

| Archivo | Subtemas obligatorios |
|---------|-----------------------|
| `routeros-v7-first-setup-and-hardening.md` | Puesta en marcha limpia sin configuración por defecto insegura: usuarios, desactivación de servicios, `MAC-Server` restringido a interfaz de gestión, firewall base, Neighbor Discovery y RoMON. |
| `mikrotik-bridge-vlan-filtering-deep-dive.md` | Guía definitiva del chip de switch y `Bridge VLAN Filtering` en RouterOS v7 (CRS3xx/CRS5xx vs RB/CCR): cómo mantener `H` (Hardware Offload) activo, puerto `bridge` (CPU) como tagged para routing/management y errores típicos. |
| `mikrotik-qos-simple-queues-and-queue-tree.md` | Control de ancho de banda: *Simple Queues*, colas igualitarias **PCQ** (*Per Connection Queue*) para que un usuario no sature la oficina, priorización de VoIP/Zoom con *Mangle + Queue Tree* y su interacción con FastTrack. |

### `guides/07-cisco/` — Especialización Cisco IOS / Catalyst

| Archivo | Subtemas obligatorios |
|---------|-----------------------|
| `cisco-ios-cli-architecture-and-hardening.md` | Modos de CLI (User EXEC, Privileged EXEC, Global Config), `service password-encryption`, `enable secret`, SSHv2, banners, VTY ACLs, `errdisable recovery` automático y `archive` de configuración. |
| `cisco-rommon-password-recovery-and-ios-upgrade.md` | Recuperación de acceso por consola (`confreg 0x2142` / `SWITCH_IGNORE_STARTUP_CFG=1`), copia y verificación SHA/MD5 de imágenes IOS por SCP/TFTP/USB y cambio de variable `boot system`. |

### `guides/08-operations/` — Mantenimiento y Operación del Día a Día

| Archivo | Subtemas obligatorios |
|---------|-----------------------|
| `network-backups-export-and-git-versioning.md` | Diferencia crítica en MikroTik entre `.backup` binario y `/export show-sensitive file=...` (`.rsc`); exportación de `running-config` en Cisco/Aruba; automatización por SSH/Oxidized y auditoría de *diffs* en Git. |
| `firmware-upgrades-and-maintenance-windows.md` | Checklist profesional antes, durante y después de actualizar RouterOS (paquetes + `/system routerboard upgrade`), Cisco IOS o switches en producción sin dejar sucursales aisladas. |
| `snmp-syslog-and-netflow-monitoring.md` | Configuración de SNMPv2c/v3 (OIDs de tráfico, CPU, temperatura y óptica), envío de logs a servidor Syslog remoto y exportación de tráfico con Traffic Flow / NetFlow v9 / IPFIX. |
