⬅️ [Volver a Referencias](README.md)

# 📚 Puertos TCP/UDP, Números de Protocolo IP y Direcciones Multicast — Consulta rápida para NetOps

**Alcance:** `Capas 2, 3, 4 y 7` | `IANA Service Name and Transport Protocol Port Number Registry`

---

## 🎯 Cómo usar esta referencia

Usá estas tablas al escribir reglas de Firewall (`INPUT` / `FORWARD`), configurar Port Forwarding (`DNAT`) o analizar capturas de paquetes (`tcpdump` / `/tool sniffer` / Wireshark) para identificar al instante qué servicio, protocolo de enrutamiento o latido de control está pasando por la red.

---

## 📊 1. Puertos TCP y UDP Críticos para Infraestructura de Red y Sistemas

| Puerto | Protocolo L4 | Servicio / Protocolo | Dirección de Tráfico Típica | Interpretación / Regla de Firewall recomendada |
|:------:|:------------:|----------------------|-----------------------------|------------------------------------------------|
| **`20 / 21`** | `TCP` | **FTP** (Datos / Control) | Cliente → Servidor | ❌ **Inseguro (texto plano):** deshabilitar en routers (`/ip service disable ftp`) y reemplazar por SCP/SFTP (`TCP 22`) |
| **`22`** | `TCP` | **SSH / SCP / SFTP** | Admin → Router/Switch/Server | ✅ **Estándar de administración:** restringir en cadena `INPUT` solo a la VLAN de Management (`VLAN 99/20`) y usar claves Ed25519 |
| **`23`** | `TCP` | **Telnet** | Admin → Equipo | ❌ **Prohibido en producción:** transmite usuario y contraseña sin cifrar. Deshabilitar siempre (`transport input ssh`) |
| **`49`** | `TCP` | **TACACS+** | Switch/Router → Servidor AAA | Autenticación, autorización y auditoría comando por comando en equipos Cisco/Enterprise |
| **`53`** | **`UDP` y `TCP`** | **DNS** | Cliente → DNS / DNS → Internet | ✅ **Ambos protocolos obligatorios:** `UDP 53` para consultas rápidas y `TCP 53` para respuestas `> 512 bytes`, DNSSEC y transferencias de zona |
| **`67 / 68`** | `UDP` | **DHCP** (`67` Servidor / `68` Cliente) | Broadcast en LAN / Unicast en Relay | Permitir en `INPUT` de las VLANs internas donde el router entrega IP (y hacia el servidor central si se usa *DHCP Relay*) |
| **`69`** | `UDP` | **TFTP** | Switch/Teléfono IP → Servidor | Usado para aprovisionar teléfonos VoIP (`Option 66`) o recuperar firmware por ROMMON/Netinstall |
| **`80 / 443`** | `TCP` (y `UDP 443`) | **HTTP (`80`) / HTTPS (`443`) / QUIC (`UDP 443`)** | Cliente → Web | ❌ Desactivar `HTTP (80)` de gestión web de routers en WAN. Recordar que `HTTP/3 (QUIC)` usa **`UDP 443`** |
| **`123`** | `UDP` | **NTP (*Network Time*)** | Equipos → Router → Pool NTP | ✅ **Crítico:** permitir que todas las VLANs internas (incluyendo cámaras aisladas) sincronicen hora contra la IP local de tu router |
| **`161 / 162`** | `UDP` | **SNMP** (`161` Polling / `162` Traps) | Monitoreo → Router (`161`) | Permitir en `INPUT` únicamente desde la IP fija de tu servidor LibreNMS / Prometheus / Zabbix |
| **`179`** | `TCP` | **BGP (*Border Gateway Protocol*)** | Router ↔ Router vecino | Sesión de enrutamiento BGP. Proteger en `INPUT` aceptando solo las IPs de tus peers BGP con `TTL Security` / MD5 |
| **`389 / 636`** | `TCP` (y `UDP 389`) | **LDAP (`389`) / LDAPS (`636`)** | Servidores/Apps → Active Directory | Consultas de directorio corporativo (preferir siempre `LDAPS 636` o StartTLS) |
| **`445`** | `TCP` | **SMB / CIFS (Carpetas Windows / Samba)** | PC → Servidor de Archivos / NAS | 🚨 **Jamás exponer a Internet ni a WiFi Invitados** (vector principal de propagación de ransomware) |
| **`500 / 4500`** | `UDP` | **IPsec IKE (`500`) y NAT-Traversal (`4500`)** | Router WAN ↔ Router WAN | Obligatorios en la cadena `INPUT` de la WAN (junto con el **Protocolo IP `50` ESP**) para túneles VPN IPsec |
| **`514 / 6514`** | `UDP / TCP` | **Syslog (`514`) / Syslog-TLS (`6514`)** | Router/Switch → Servidor Syslog | Envío de logs en tiempo real hacia la "caja negra" central (Graylog / Loki / rsyslog) |
| **`554`** | `TCP / UDP` | **RTSP (Streaming de Video IP)** | Grabador NVR → Cámara IP | Flujo de video en vivo de cámaras Dahua/Hikvision/ONVIF hacia el NVR |
| **`1812 / 1813`** | `UDP` | **RADIUS** (`1812` Auth / `1813` Accounting) | Switch/AP/Router → Servidor RADIUS | Autenticación `802.1X`, WiFi `WPA2/WPA3-Enterprise` y usuarios PPPoE/VPN |
| **`2055 / 4739 / 6343`** | `UDP` | **NetFlow (`2055`) / IPFIX (`4739`) / sFlow (`6343`)** | Router/Switch → Colector | Telemetría de flujos de tráfico para saber qué IP consume el ancho de banda |
| **`3306 / 5432 / 1433`** | `TCP` | **MySQL (`3306`) / PostgreSQL (`5432`) / SQL Server (`1433`)** | App Server → Base de Datos | Solo deben permitirse desde la VLAN de servidores de aplicación hacia la base de datos |
| **`3389`** | `TCP / UDP` | **RDP (Escritorio Remoto Windows)** | Admin → Windows | 🚨 **Prohibido hacer Port Forwarding (`DNAT`) del puerto 3389 desde Internet:** acceder siempre a través de VPN WireGuard/IPsec |
| **`3702 / 37777 / 8000`** | `TCP / UDP` | **ONVIF (`UDP 3702`) / Dahua (`TCP 37777`) / Hikvision (`TCP 8000`)** | NVR / App → Cámara / NVR | Protocolos propietarios y de descubrimiento de videovigilancia CCTV |
| **`8291`** | `TCP` | **MikroTik WinBox** | Admin → Router MikroTik | 🚨 **Bloquear siempre en WAN** y restringir en `/ip service set winbox address=10.1.20.0/24,10.1.99.0/24` |
| **`8728 / 8729`** | `TCP` | **MikroTik API (`8728`) / API-SSL (`8729`)** | Sistema de Gestión → MikroTik | Deshabilitar si no se usa un sistema de facturación/automatización externo |
| **`51820`** | `UDP` | **WireGuard VPN** | Peer ↔ Servidor WireGuard | Puerto estándar por defecto para túneles modernos WireGuard (muy rápido y silencioso ante escaneos) |

---

## 📊 2. Números de Protocolo IP (Capa 3 — Campo `Protocol` del Header IPv4)

> ⚠️ **Atención al configurar Firewalls:** Los protocolos de esta tabla (excepto TCP y UDP) **NO tienen número de puerto TCP/UDP** porque viven directamente encima de IP en Capa 3. En tu firewall debés filtrarlos por **`protocol=`**, no por `dst-port=`:

| Número Protocolo IP | Nombre en Firewall | Qué protocolo es | Por qué es crítico no bloquearlo por error en la cadena `INPUT` |
|:-------------------:|--------------------|------------------|-----------------------------------------------------------------|
| **`1`** | **`icmp`** | **ICMPv4** | Transporta el `ping`, `traceroute` (`Time Exceeded`) y el vital **`Fragmentation Needed` (Type 3 Code 4)** para que funcione el MTU (PMTUD) |
| **`2`** | **`igmp`** | **IGMP** | Gestión de grupos Multicast en la LAN (IPTV, audio/video multicast) |
| **`6`** | **`tcp`** | **TCP** | Transporte confiable orientado a conexión con puertos `0–65535` |
| **`17`** | **`udp`** | **UDP** | Transporte sin conexión de baja latencia con puertos `0–65535` |
| **`47`** | **`gre`** | **GRE (*Generic Routing Encapsulation*)** | Encapsulamiento de túneles L3 (`GRE`, `EoIP` de MikroTik usa protocolo GRE) |
| **`50`** | **`ipsec-esp`** | **ESP (*Encapsulating Security Payload*)** | Transporta los paquetes cifrados de un túnel **IPsec** cuando no hay NAT en el medio |
| **`58`** | **`icmpv6`** | **ICMPv6** | **Indispensable en IPv6:** además del ping, reemplaza a ARP (*Neighbor Discovery*) y entrega rutas (*Router Advertisement*) |
| **`89`** | **`ospf`** | **OSPF** | **¡OSPF no usa TCP ni UDP!** Si en la cadena `INPUT` entre dos routers no permitís `protocol=ospf` (`89`), la vecindad OSPF jamás levanta |
| **`112`** | **`vrrp`** | **VRRP** | **¡VRRP no usa TCP ni UDP!** Si bloqueás `protocol=vrrp` (`112`) en `INPUT`, los dos routers no se escuchan y entran en **Split-Brain (Doble Master)** |

---

## 📊 3. Direcciones Multicast y MACs de Control que verás en `tcpdump` / Wireshark

| Dirección Multicast / MAC | Capa | Protocolo | Quién la envía y qué significa verla en una captura |
|---------------------------|:----:|-----------|-----------------------------------------------------|
| **`FF:FF:FF:FF:FF:FF`** | L2 | **Broadcast Ethernet** | Grito a todos los puertos de la misma VLAN (`ARP Request`, `DHCP Discover`) |
| **`01:80:C2:00:00:00`** | L2 | **STP / RSTP (`802.1D / 802.1w`)** | Tramas **BPDU** enviadas cada `2 seg` entre switches para elegir Root Bridge y bloquear bucles |
| **`01:80:C2:00:00:02`** | L2 | **LACP (`802.3ad`)** | Tramas **LACPDU** que negocian y mantienen vivo un grupo EtherChannel / Bonding |
| **`01:80:C2:00:00:0E`** | L2 | **LLDP (`802.1AB`)** | Anuncios de descubrimiento de equipos vecinos por puerto físico |
| **`01:00:0C:CC:CC:CC`** | L2 | **Cisco CDP / VTP / PAgP** | Protocolos propietarios de Capa 2 de Cisco |
| **`00:00:5E:00:01:XX`** | L2 | **MAC Virtual VRRP** | MAC compartida por el router `Master` de VRRP (`XX` = `VRID` en hexadecimal, ej. `0A` = VRID 10) |
| **`00:00:0C:07:AC:XX`** | L2 | **MAC Virtual Cisco HSRP v1** | MAC compartida por el router `Active` de HSRP (`00:00:0C:9F:FXXX` en HSRP v2) |
| **`224.0.0.1` / `224.0.0.2`** | L3 | **All Hosts (`.1`) / All Routers (`.2`)** | Todos los equipos (`.1`) o todos los routers (`.2`, usado también por HSRP v1) del segmento local |
| **`224.0.0.5` / `224.0.0.6`** | L3 | **OSPF Routers (`.5`) / OSPF DR (`.6`)** | Saludos `Hello` de OSPF cada `10 seg` (`.5`) y actualizaciones hacia el *Designated Router* (`.6`) |
| **`224.0.0.18`** | L3 | **VRRP** | Latidos del router `Master` VRRP cada `1 seg` (Protocolo IP `112`) |
| **`224.0.0.102`** | L3 | **Cisco HSRP v2 / GLBP** | Latidos del router `Active` HSRP v2 (`UDP 1985`) |
| **`224.0.0.251` (`UDP 5353`)** | L3/L4 | **mDNS (Bonjour / AirPrint / Chromecast)** | Descubrimiento local sin servidor DNS (solo vive dentro de la misma VLAN salvo que actives un *mDNS Repeater / Avahi*) |
| **`255.255.255.255:5678`** | L3/L4 | **MikroTik MNDP** | Paquete `UDP 5678` con el que WinBox descubre routers MikroTik vecinos por dirección MAC en Capa 2 |

---

## ⚡ Comandos rápidos de verificación

```text
# Cisco IOS: Ver qué servicios/puertos escucha el router y conexiones activas
show control-plane host open-ports
show tcp brief

# MikroTik RouterOS v7: Ver servicios administrativos activos en el router y conexiones Conntrack
/ip service print
/ip firewall connection print where protocol=ospf or protocol=vrrp

# Linux: Ver puertos locales abiertos y capturar protocolos de control L2/L3 en vivo
ss -tulnp
tcpdump -ni eth0 -e 'stp or ether proto 0x88cc or proto 89 or proto 112'
```

---

## 🔗 Ver también

- [`stateful-firewalls-and-zone-segmentation`](../concepts/stateful-firewalls-and-zone-segmentation.md) — Cómo filtrar correctamente estos puertos y protocolos en las cadenas `INPUT` y `FORWARD`
- [`dhcp-dns-and-network-services`](../concepts/dhcp-dns-and-network-services.md) — Funcionamiento interno de DHCP (`67/68`), DNS (`53`) y NTP (`123`)
