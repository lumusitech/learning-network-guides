# Catálogo y Estándares de Calidad para `concepts/`

Este documento define el estándar de ingeniería y el catálogo completo de archivos conceptuales para `learning-network-guides`. Todo modelo que cree o edite un archivo en `concepts/` debe cumplir esta especificación.

---

## 1. Estándar de profundidad técnica (Qué distingue un documento profesional de uno superficial)

Un documento en `concepts/` **NO es un resumen genérico de Wikipedia**. Debe estar escrito desde la perspectiva de un **Ingeniero de Redes / NetOps Senior** que le enseña a un técnico cómo funciona la red de verdad:

1. **Precisión en estándares y números reales:**
   - Mencionar siempre el estándar real (`IEEE 802.1Q`, `IEEE 802.1w`, `IEEE 802.3ad`, `IEEE 802.3af/at/bt`, `RFC 1918`, `RFC 2131`, `RFC 2328`).
   - Incluir tamaños reales de cabeceras y tiempos cuando aplique (ej. tag 802.1Q = 4 bytes; MTU Ethernet estándar = 1500 bytes, trama completa = 1518 bytes o 1522 con VLAN; timers STP Hello = 2s, Forward Delay = 15s, Max Age = 20s; tabla MAC aging = 300s por defecto).
2. **Traducción entre marcas (El diferencial del repositorio):**
   - Explicar siempre por qué distintos fabricantes llaman distinto a lo mismo:
     - Ejemplo VLANs: Cisco habla de puerto `access` y `trunk` (`native vlan`), mientras que MikroTik (`Bridge VLAN Filtering`), Aruba y TP-Link hablan de puerto `untagged`, `tagged` y `PVID`.
     - Ejemplo Agregación de enlaces: Estándar `802.3ad LACP` → Cisco lo llama `EtherChannel / Port-channel`, MikroTik y Linux lo llaman `Bonding (mode 802.3ad)`, Aruba/HP lo llama `Trunk` (¡ojo con la confusión en HP donde "Trunk" significa LACP y no VLAN trunk!).
3. **Foco en diagnóstico y mantenimiento:**
   - Cada concepto debe dejar claro **qué se rompe cuando este mecanismo falla** y cuáles son los indicadores (contadores CRC/FCS, flapping de MAC, tormenta de broadcast, agotamiento de conntrack, blackhole de MTU).

---

## 2. Catálogo maestro de `concepts/` (Orden pedagógico)

Al crear cualquiera de estos 14 conceptos fundacionales, usar exactamente el nombre de archivo indicado y cubrir todos los puntos obligatorios listados:

### Bloque 1: Fundamentos y Modelos de Diagnóstico

| # | Archivo (`concepts/`) | Capa | Subtemas obligatorios que debe cubrir |
|---|-----------------------|------|---------------------------------------|
| 1 | `how-to-think-like-network-engineer.md` | 1–7 | Metodologías de troubleshooting (Bottom-Up L1→L7, Top-Down, Divide & Conquer, Follow-the-Path); diferencia entre plano de datos (forwarding) y plano de control; baseline de red; cambio de una sola variable; ventanas de mantenimiento seguras (Safe Mode / reload in). |
| 2 | `osi-and-tcp-ip-models.md` | 1–7 | Las 7 capas OSI vs 4/5 capas TCP/IP; encapsulamiento y desencapsulamiento paso a paso; PDUs reales (Bits, Trama/Frame, Paquete/Packet, Segmento/Datagrama, Datos); qué cabecera agrega cada capa (MAC origen/destino + EtherType, IP origen/destino + TTL + Protocol, Puerto origen/destino + Flags); embudo de aislamiento de fallas por capa. |
| 3 | `physical-layer-cables-fiber-poe.md` | 1 | Cobre par trenzado (Cat5e, Cat6, Cat6A, UTP vs FTP/S/FTP, normas T568A/B, límite 100m); Fibra óptica (Monomodo OS2 9/125µm vs Multimodo OM3/OM4 50/125µm, conectores LC/SC, transceptores SFP/SFP+/QSFP, BiDi, lectura de niveles ópticos dBm TX/RX con DDM/DOM); Negociación Auto-MDIX, Speed y Full/Half Duplex (por qué un mismatch causa late collisions y CRC); PoE activo (802.3af 15.4W, 802.3at 30W, 802.3bt 60/100W) vs PoE pasivo (24V/48V y riesgo de quemar equipos). |

### Bloque 2: Capa 2 — Switching, Ethernet y Segmentación

| # | Archivo (`concepts/`) | Capa | Subtemas obligatorios que debe cubrir |
|---|-----------------------|------|---------------------------------------|
| 4 | `ethernet-mac-and-arp.md` | 2 | Estructura de la trama Ethernet II (Preámbulo, SFD, MAC Destino/Origen, EtherType, Payload 46-1500B, FCS/CRC32); direcciones MAC (OUI, Unicast, Broadcast `FF:FF:FF:FF:FF:FF`, Multicast `01:00:5E...`); cómo aprende un switch (tabla CAM/FDB: Learning, Forwarding, Flooding de unknown unicast, Aging 300s); dominios de colisión vs dominios de broadcast; protocolo ARP (Request broadcast, Reply unicast, caché ARP, Gratuitous ARP para failover VRRP y detección de IP duplicada). |
| 5 | `vlans-tagged-untagged-and-trunks.md` | 2 | Qué problema resuelve una VLAN (segmentar dominios de broadcast sin comprar más switches); estándar IEEE 802.1Q (inyección del tag de 4 bytes: TPID `0x8100`, PCP/QoS, DEI, VID 1-4094); el modelo mental unificado: **Ingress (PVID)** vs **Egress (Tagged/Untagged)**; equivalencia exacta entre Cisco (`access` / `trunk` / `native vlan`), MikroTik (`Bridge VLAN Filtering`: `pvid`, `tagged`, `untagged`, `frame-types`), Aruba/TP-Link/Ubiquiti y Linux; riesgos de la VLAN 1 y Native VLAN mismatch. |
| 6 | `spanning-tree-and-loop-prevention.md` | 2 | Por qué un bucle en Capa 2 destruye una red en segundos (tramas Ethernet no tienen TTL → Broadcast Storm, multiplicación de tramas y MAC Table Flapping); cómo funciona STP (802.1D) y RSTP (802.1w): elección del Root Bridge (Bridge ID = Prioridad 32768 + MAC), roles de puerto (Root, Designated, Alternate/Blocked) y estados; por qué siempre hay que fijar el Root Bridge manualmente en el switch core; mecanismos de protección imprescindibles: PortFast / Edge Port, BPDU Guard y Loop Guard. |
| 7 | `link-aggregation-and-redundancy-l2.md` | 2 | Por qué conectar 2 cables entre dos switches sin configurar LACP crea un bucle o STP bloquea uno; estándar IEEE 802.3ad / 802.1AX (LACP activo vs pasivo vs estático); algoritmos de balanceo por hash (`src-dst-mac`, `src-dst-ip`, `layer-3-and-4`) y por qué 2 enlaces de 1 Gbps **no** dan 2 Gbps a una sola transferencia TCP pero sí a múltiples flujos; requisitos de coincidencia (velocidad, duplex, VLANs); terminología multi-vendor (Cisco `EtherChannel / Port-channel`, MikroTik/Linux `Bonding`, HP/Aruba `Trunk`). |

### Bloque 3: Capa 3 — Direccionamiento, Enrutamiento y Redundancia

| # | Archivo (`concepts/`) | Capa | Subtemas obligatorios que debe cubrir |
|---|-----------------------|------|---------------------------------------|
| 8 | `ipv4-addressing-subnetting-and-vlsm.md` | 3 | Estructura del paquete IPv4 (TTL, Protocol, IP origen/destino); máscara CIDR (`/8` a `/32`), cálculo rápido de tamaño de subred ($2^{32-n}$), dirección de red, primer/último host y broadcast; bloques privados RFC 1918 (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`), CGNAT RFC 6598 (`100.64.0.0/10` — crítico en ISPs), Link-Local APIPA (`169.254.0.0/16`) y enlaces punto a punto (`/30` vs `/31` RFC 3021); VLSM y cómo diseñar un plan de direccionamiento limpio por sede y VLAN (`10.<sede>.<vlan>.<host>`). |
| 9 | `routing-fundamentals-static-and-dynamic.md` | 3 | Cómo reenvía paquetes un router (reescritura de MAC en cada salto L2 manteniendo IP origen/destino L3 intactas y decrementando TTL); la tabla de enrutamiento (RIB vs FIB); regla suprema: **Longest Prefix Match** (por qué `/25` siempre le gana a `/24` sin importar la distancia administrativa); Distancia Administrativa (AD) comparada entre Cisco vs MikroTik vs Linux (Connected, Static, eBGP, OSPF); rutas estáticas, default gateway (`0.0.0.0/0`), rutas flotantes para failover y cuándo pasar a routing dinámico (OSPF / BGP); Inter-VLAN routing (Router-on-a-Stick vs Switch L3 con SVIs). |
| 10 | `first-hop-redundancy-vrrp-hsrp.md` | 3 | El punto único de falla del Default Gateway estático en las PCs/servidores; cómo funcionan FHRP (VRRP RFC 5798 estándar en MikroTik/Linux/Aruba vs HSRP propietario de Cisco): IP virtual (VIP) compartida + MAC virtual (`00:00:5E:00:01:<VRID>`), router Master/Active vs Backup/Standby, anuncios multicast, Preemption y Object/Interface Tracking (qué pasa si cae la WAN del router Master pero su interfaz LAN sigue arriba). |

### Bloque 4: Capa 4 a 7 — Transporte, NAT, Firewalls, Servicios y Operación

| # | Archivo (`concepts/`) | Capa | Subtemas obligatorios que debe cubrir |
|---|-----------------------|------|---------------------------------------|
| 11 | `tcp-udp-mtu-and-nat-conntrack.md` | 3–4 | TCP (3-way handshake `SYN → SYN-ACK → ACK`, cierre `FIN`/`RST`, ventana deslizante) vs UDP; puertos efímeros vs bien conocidos; **MTU vs MSS** (Ethernet 1500B → MSS 1460B; qué pasa en PPPoE 1492B o túneles WireGuard/IPsec 1420B cuando Path MTU Discovery falla por ICMP bloqueado, y cómo lo resuelve el *TCP MSS Clamping*); cómo funciona la tabla **Connection Tracking (Conntrack)** y los 4 tipos de NAT: Source NAT / Masquerade (PAT), Destination NAT (Port Forwarding), NAT 1:1 y Hairpin NAT (acceder desde la LAN a un servidor interno usando la IP pública). |
| 12 | `stateful-firewalls-and-zone-segmentation.md` | 3–7 | Diferencia entre ACL stateless (filtro paquete a paquete en switch L3/router) y Firewall Stateful (basado en estados `ESTABLISHED`, `RELATED`, `NEW`, `INVALID`); el modelo mental de flujos: tráfico **hacia el propio router** (`INPUT` en MikroTik/Linux) vs tráfico **que atraviesa el router** (`FORWARD`) vs tráfico **originado por el router** (`OUTPUT`); diseño de seguridad por zonas (WAN, LAN Corporativa, Servidores/DMZ, Cámaras/IoT, Invitados) y principio de mínimo privilegio. |
| 13 | `dhcp-dns-and-network-services.md` | 2–7 | Ciclo DHCP **DORA** (Discover broadcast, Offer, Request, Acknowledge), tiempos de lease (T1 50%, T2 87.5%), por qué el broadcast no cruza routers y cómo funciona **DHCP Relay (`ip helper-address`)** en redes con múltiples VLANs; ataque de Rogue DHCP y cómo lo previene DHCP Snooping; flujo de resolución DNS (recursivo vs autoritativo, registros A/AAAA/CNAME/PTR/SRV, Split-Horizon DNS interno vs externo); NTP y por qué un reloj desincronizado rompe certificados TLS, logs y correlación de incidentes. |
| 14 | `netops-day-to-day-maintenance-and-observability.md` | 1–7 | Cómo se mantiene una red en producción sin incendios: las 3 patas de la observabilidad de red (**SNMP v2c/v3** para métricas de interfaces/CPU/óptica, **Syslog** centralizado para eventos, **NetFlow/sFlow** para saber quién consume el ancho de banda); descubrimiento de topología con **LLDP / CDP / MNDP**; gestión de configuración y backups (texto plano `.rsc` / `running-config` en Git vs backups binarios); anatomía de una ventana de mantenimiento profesional (pre-checks, backup, Safe Mode / rollback timer, post-checks). |

---

## 3. Reglas de formato y Markdownlint (Cero errores en `pnpm lint:md`)

Para que cualquier archivo generado pase `pnpm lint:md` al primer intento:

1. **Bloques de código siempre con lenguaje:** Nunca escribir ` ``` ` solo. Usar ` ```text ` para diagramas ASCII y salidas, ` ```bash ` para comandos Linux, ` ```routeros ` o ` ```text ` para MikroTik, ` ```cisco ` o ` ```text ` para Cisco IOS.
2. **Líneas en blanco obligatorias:**
   - Siempre dejar una línea en blanco antes y después de cada título (`#`, `##`, `###`).
   - Siempre dejar una línea en blanco antes y después de cada lista (`-` o `1.`), tabla (`|`) y bloque de código (` ``` `).
3. **Listas y viñetas:**
   - Usar siempre guion `-` para listas desordenadas (regla `MD004`).
   - Indentación de sublistas: múltiplos de 2 espacios (regla `MD007`).
4. **Enlaces internos:**
   - En archivos dentro de `concepts/`, referenciar a otros conceptos en el mismo directorio directamente como `[`nombre`](archivo.md) — descripción breve` (sin `../`).
   - Para subir a otras carpetas del repo desde `concepts/`, usar `../guides/...`, `../scenarios/...`, `../reference/...`.
   - Prohibido dejar enlaces vacíos `[texto]()`.
