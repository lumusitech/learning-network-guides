⬅️ [Volver a Referencias](README.md)

# 📚 Tabla CIDR IPv4, Wildcard Masks, VLSM y Rangos Especiales — Consulta rápida para NetOps

**Alcance:** `Capa 3 (IPv4)` | `RFC 791`, `RFC 4632 (CIDR)`, `RFC 1918`, `RFC 6598 (CGNAT)`, `RFC 3021 (/31)`, `RFC 5735`

---

## 🎯 Cómo usar esta referencia

Usá esta tabla durante el diseño de subredes, configuración de interfaces o creación de ACLs (que en Cisco/Aruba exigen **Wildcard Mask**) para conocer al instante el tamaño del bloque, la cantidad de hosts útiles y si una dirección IP vista en consola pertenece a un bloque especial (como CGNAT o APIPA).

---

## 📊 1. Tabla Maestra de Prefijos CIDR (`/32` a `/8`), Máscaras y Wildcards

| Prefijo CIDR | Máscara Decimal | Wildcard Mask (Cisco ACL) | Total IPs ($2^{32-N}$) | Hosts Útiles ($Total-2$) | Equivalente en `/24` | Interpretación / Uso recomendado en campo |
|:------------:|-----------------|---------------------------|:----------------------:|:------------------------:|:--------------------:|-------------------------------------------|
| **`/32`** | `255.255.255.255` | `0.0.0.0` | `1` | `1` (Host exacto) | `1/256` | Loopback de router (OSPF/BGP Router-ID), VIP de VRRP en MikroTik, regla a 1 IP |
| **`/31`** | `255.255.255.254` | `0.0.0.1` | `2` | `2` (`RFC 3021`) | `1/128` | Enlace punto a punto entre 2 routers modernos (sin IP de red ni broadcast) |
| **`/30`** | `255.255.255.252` | `0.0.0.3` | `4` | **`2`** (`.1` y `.2`) | `1/64` | **Estándar universal punto a punto** (enlaces entre routers, WAN corporativa, VPN Site-to-Site) |
| **`/29`** | `255.255.255.248` | `0.0.0.7` | `8` | **`6`** (`.1` a `.6`) | `1/32` | Enlace WAN con par de firewalls en VRRP/HSRP (1 IP ISP + 2 reales + 1 VIP) |
| **`/28`** | `255.255.255.240` | `0.0.0.15` | `16` | **`14`** (`.1` a `.14`) | `1/16` | Subred chica para switches de gestión, DMZ pequeña o servidores críticos |
| **`/27`** | `255.255.255.224` | `0.0.0.31` | `32` | **`30`** (`.1` a `.30`) | `1/8` | Sucursal chica, VLAN de impresoras, relojes de personal o control de acceso |
| **`/26`** | `255.255.255.192` | `0.0.0.63` | `64` | **`62`** (`.1` a `.62`) | `1/4` | Un cuarto de `/24`: piso de oficina mediano o VLAN de cámaras IP |
| **`/25`** | `255.255.255.128` | `0.0.0.127` | `128` | **`126`** | `1/2` | Medio `/24` (Bloque 1: `.0–.127`, Bloque 2: `.128–.255`) |
| **`/24`** | `255.255.255.0` | `0.0.0.255` | `256` | **`254`** (`.1` a `.254`) | **`1 × /24`** | 🏆 **Estándar corporativo por VLAN:** fácil lectura humana (tercer octeto = VLAN) |
| **`/23`** | `255.255.254.0` | `0.0.1.255` | `512` | **`510`** | `2 × /24` | VLAN de **WiFi Corporativo o Invitados** de alta densidad (`10.1.200.0` a `10.1.201.255`) |
| **`/22`** | `255.255.252.0` | `0.0.3.255` | `1.024` | **`1.022`** | `4 × /24` | Campus, colegios, hoteles o eventos con gran cantidad de dispositivos móviles |
| **`/21`** | `255.255.248.0` | `0.0.7.255` | `2.048` | `2.046` | `8 × /24` | Agregación de sucursal mediana |
| **`/20`** | `255.255.240.0` | `0.0.15.255` | `4.096` | `4.094` | `16 × /24` | Bloque típico de VPC en nube (AWS/GCP) o asignación a ISP regional |
| **`/19`** | `255.255.224.0` | `0.0.31.255` | `8.192` | `8.190` | `32 × /24` | Agregación regional de red |
| **`/18`** | `255.255.192.0` | `0.0.63.255` | `16.384` | `16.382` | `64 × /24` | Cuarto de `/16` |
| **`/17`** | `255.255.128.0` | `0.0.127.255` | `32.768` | `32.766` | `128 × /24` | Medio `/16` |
| **`/16`** | `255.255.0.0` | `0.0.255.255` | `65.536` | **`65.534`** | **`256 × /24`** | 🏆 **Resumen por Sede/Sucursal** (`10.<Sede>.0.0/16`): engloba hasta 256 VLANs `/24` en 1 sola ruta |
| **`/12`** | `255.240.0.0` | `0.15.255.255` | `1.048.576` | `1.048.574` | `4.096 × /24` | Bloque completo `172.16.0.0/12` (`172.16.0.0` – `172.31.255.255`) |
| **`/10`** | `255.192.0.0` | `0.63.255.255` | `4.194.304` | `4.194.302` | `16.384 × /24` | Bloque completo **CGNAT** `100.64.0.0/10` (`100.64.0.0` – `100.127.255.255`) |
| **`/8`** | `255.0.0.0` | `0.255.255.255` | `16.777.216` | `16.777.214` | `65.536 × /24` | Bloque completo privado Clase A `10.0.0.0/8` |

---

## 📊 2. Subdivisiones Rápidas VLSM dentro de un `/24` (Para enlaces y salas chicas)

### División en `/30` (Enlaces Punto a Punto entre Routers — Salto de a 4)

| Subred `/30` | IP de Red (No usable) | Host 1 (Router A) | Host 2 (Router B) | Broadcast (No usable) | Interpretación / Acción en campo |
|--------------|:---------------------:|:-----------------:|:-----------------:|:---------------------:|----------------------------------|
| `x.x.x.0/30` | `.0` | **`.1`** | **`.2`** | `.3` | Enlace P2P #1 (ej. Core ↔ Firewall) |
| `x.x.x.4/30` | `.4` | **`.5`** | **`.6`** | `.7` | Enlace P2P #2 (ej. Túnel VPN Sede 1 ↔ Sede 2) |
| `x.x.x.8/30` | `.8` | **`.9`** | **`.10`** | `.11` | Enlace P2P #3 (ej. Túnel VPN Sede 1 ↔ Sede 3) |
| `x.x.x.12/30` | `.12` | **`.13`** | **`.14`** | `.15` | Enlace P2P #4 (la IP de red es siempre múltiplo de 4) |

### División en `/29` (8 IPs, 6 útiles — Salto de a 8) y `/28` (16 IPs, 14 útiles — Salto de a 16)

| Prefijo | Subred | IP de Red | Rango de Hosts Útiles | Broadcast | Uso típico |
|:-------:|--------|:---------:|:---------------------:|:---------:|------------|
| **`/29`** | `x.x.x.0/29` | `.0` | **`.1` a `.6`** (6 hosts) | `.7` | Subred de tránsito con redundancia VRRP/HSRP |
| **`/29`** | `x.x.x.8/29` | `.8` | **`.9` a `.14`** (6 hosts) | `.15` | Segundo bloque `/29` |
| **`/28`** | `x.x.x.0/28` | `.0` | **`.1` a `.14`** (14 hosts) | `.15` | Primer bloque `/28` (ideal DMZ chica) |
| **`/28`** | `x.x.x.16/28` | `.16` | **`.17` a `.30`** (14 hosts) | `.31` | Segundo bloque `/28` (múltiplos de 16) |

---

## 📊 3. Rangos IPv4 Especiales (IANA / IETF RFCs)

| Rango CIDR | Primera IP – Última IP | Estándar | Nombre Oficial | Interpretación / Acción en campo |
|------------|------------------------|----------|----------------|----------------------------------|
| **`0.0.0.0/8`** | `0.0.0.0` – `0.255.255.255` | `RFC 1122` | *This host / Default Route* | `0.0.0.0/0` representa la ruta por defecto; `0.0.0.0` es el origen de un cliente DHCP antes de recibir IP |
| **`10.0.0.0/8`** | `10.0.0.0` – `10.255.255.255` | `RFC 1918` | **Privada Clase A** | ✅ **Recomendado para LANs y VLANs empresariales** (`10.<Sede>.<VLAN>.<Host>/24`). No enrutable en Internet público |
| **`100.64.0.0/10`** | `100.64.0.0` – `100.127.255.255` | `RFC 6598` | **CGNAT (*Shared Address Space*)** | 🚨 **Alerta en boca WAN:** tu ISP te metió detrás de Carrier-Grade NAT. No te funcionará ningún Port Forwarding (`DNAT`) entrante |
| **`127.0.0.0/8`** | `127.0.0.0` – `127.255.255.255` | `RFC 1122` | **Loopback del Host** | Tráfico interno de la propia máquina (`localhost = 127.0.0.1`). Nunca sale por el cable |
| **`169.254.0.0/16`** | `169.254.0.0` – `169.254.255.255` | `RFC 3927` | **Link-Local / APIPA** | ❌ **Falla de DHCP:** la PC/cámara pidió IP por DHCP y nadie le contestó. Revisar PVID/Trunk de la VLAN o servidor DHCP |
| **`172.16.0.0/12`** | `172.16.0.0` – `172.31.255.255` | `RFC 1918` | **Privada Clase B** | ✅ Ideal para redes de contenedores Docker/K8s, DMZ o túneles VPN. *(¡Ojo: `172.32.x.x` ya es IP pública!)* |
| **`192.0.2.0/24`** | `192.0.2.0` – `192.0.2.255` | `RFC 5737` | `TEST-NET-1` | Reservado para documentación y ejemplos (igual que `198.51.100.0/24` y `203.0.113.0/24`) |
| **`192.168.0.0/16`** | `192.168.0.0` – `192.168.255.255` | `RFC 1918` | **Privada Clase C** | ⚠️ Evitar `192.168.0.0/24` y `192.168.1.0/24` en oficinas porque choca con el WiFi hogareño de empleados en VPN |
| **`224.0.0.0/4`** | `224.0.0.0` – `239.255.255.255` | `RFC 5771` | **Multicast** | Protocolos de control: `224.0.0.5/6` (OSPF), `224.0.0.18` (VRRP), `224.0.0.102` (HSRP), `224.0.0.251` (mDNS) |
| **`255.255.255.255/32`** | `255.255.255.255` | `RFC 919` | **Limited Broadcast** | Broadcast local a toda la VLAN actual (usado por DHCP Discover). Nunca cruza un router |

---

## 📊 4. Plantilla Estándar de Direccionamiento Empresarial (`10.<Sede>.<VLAN>.<Host>/24`)

| VLAN ID | Nombre de Zona / Segmento | Subred Sede 1 (Central) | Subred Sede 2 (Sucursal) | Default Gateway | Política de Firewall por defecto |
|:-------:|---------------------------|-------------------------|--------------------------|-----------------|----------------------------------|
| **`10`** | **Staff / Administración** | `10.1.10.0/24` | `10.2.10.0/24` | `.1` | Sale a Internet y accede solo a puertos de aplicaciones en VLAN 40 |
| **`20`** | **IT / Sistemas** | `10.1.20.0/24` | `10.2.20.0/24` | `.1` | Acceso administrativo a servidores y VLAN 99 de Management |
| **`30`** | **Telefonía VoIP** | `10.1.30.0/24` | `10.2.30.0/24` | `.1` | Prioridad QoS (`DSCP EF / CoS 5`), solo habla con la central PBX |
| **`40`** | **Servidores Internos** | `10.1.40.0/24` | `10.2.40.0/24` | `.1` | No inicia conexiones a PCs; solo responde (`ESTABLISHED`) |
| **`90`** | **DMZ (Públicos)** | `10.1.90.0/24` | — | `.1` | Recibe `DNAT` desde WAN; bloqueado para iniciar tráfico hacia la LAN |
| **`99`** | **Management (Switches/APs)** | `10.1.99.0/24` | `10.2.99.0/24` | `.1` | Solo accesible por SSH/HTTPS/WinBox desde VLAN 20 o VPN Admin |
| **`100`** | **Cámaras IP / CCTV / IoT** | `10.1.100.0/24` | `10.2.100.0/24` | `.1` | **Bloqueo total de salida a WAN y LAN**; solo el NVR las consulta |
| **`200`** | **WiFi Invitados (*Guest*)** | `10.1.200.0/23` (`510 IPs`) | `10.2.200.0/24` | `.1` | Solo salida a WAN (`80/443/DNS`), aislado de todo `10.0.0.0/8` |

---

## ⚡ Comandos rápidos de verificación

```text
# Cisco IOS: Ver IPs e interfaces y verificar qué ruta toma una subred
show ip interface brief
show ip route 10.2.10.50

# MikroTik RouterOS v7: Ver IPs, redes calculadas y probar ruta
/ip address print
/ip route check 10.2.10.50

# Linux: Ver IPs en formato breve y calcular subred con ipcalc
ip -br addr show
ipcalc 10.1.200.0/23
```

---

## 🔗 Ver también

- [`ipv4-addressing-subnetting-and-vlsm`](../concepts/ipv4-addressing-subnetting-and-vlsm.md) — Explicación conceptual completa de CIDR, VLSM y CGNAT
- [`multivendor-cli-rosetta-stone`](multivendor-cli-rosetta-stone.md) — Equivalencia de comandos de Capa 3 entre Cisco, MikroTik, Aruba y Linux
