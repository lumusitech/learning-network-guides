⬅️ [Volver a Referencias](README.md)

# 📚 Estándares IEEE 802 e IETF RFCs Esenciales — Consulta rápida para NetOps

**Alcance:** `Capas 1 a 7` | `IEEE 802.1`, `IEEE 802.3`, `IEEE 802.11`, `IETF RFCs`

---

## 🎯 Cómo usar esta referencia

Cuando en la consola o interfaz web de un switch Cisco, MikroTik, Aruba o Ubiquiti ves una casilla que dice **`802.1Q`**, **`802.1w`**, **`802.3ad`**, **`802.1AB`** o **`802.11r`**, esta tabla te dice en 5 segundos qué protocolo es, qué problema resuelve y con qué función de otra marca es compatible.

---

## 📊 1. Estándares IEEE 802.1 (Switching, VLANs, Spanning Tree, Seguridad y Gestión)

| Estándar IEEE | Nombre del Protocolo | Capa | Qué hace en 1 línea y compatibilidad multi-vendor |
|:-------------:|----------------------|:----:|---------------------------------------------------|
| **`IEEE 802.1D`** | **STP (*Spanning Tree Protocol*)** | L2 | Prevención de bucles L2 clásica. **Obsoleto en convergencia (tarda 30–50 seg)**; reemplazar siempre por `802.1w (RSTP)` |
| **`IEEE 802.1p`** | **CoS (*Class of Service* / PCP)** | L2 | Los **3 bits de prioridad QoS (`0` a `7`)** que viajan adentro de la etiqueta VLAN `802.1Q` (`5` = Voz VoIP, `4` = Video) |
| **`IEEE 802.1Q`** | **VLAN Tagging** | L2 | **El estándar universal de VLANs:** inyecta el tag de `4 bytes` (`TPID 0x8100` + `VID 1–4094`) en los enlaces Trunk |
| **`IEEE 802.1w`** | **RSTP (*Rapid Spanning Tree*)** | L2 | 🏆 **Estándar recomendado contra bucles L2:** converge en **`< 1 segundo`** y es 100% compatible entre MikroTik, Cisco, Aruba y Linux |
| **`IEEE 802.1s`** | **MSTP (*Multiple Spanning Tree*)** | L2 | Permite agrupar decenas de VLANs en 2 o 3 árboles STP distintos para balancear carga por distintos enlaces troncales |
| **`IEEE 802.1X`** | **Port-Based NAC (Autenticación)** | L2 | Exige usuario/certificado contra un servidor **RADIUS** antes de habilitar una boca de switch o conectarse al WiFi `WPA2/WPA3-Enterprise` |
| **`IEEE 802.1AB`** | **LLDP (*Link Layer Discovery*)** | L2 | 🏆 **Descubrimiento universal de vecinos:** reemplaza al propietario Cisco CDP y permite que switches de distintas marcas se vean entre sí |
| **`IEEE 802.1ad`** | **QinQ (*Provider Bridging*)** | L2 | Apila **dos etiquetas VLAN (`Outer Tag` del ISP + `Inner Tag` del cliente)** con `TPID 0x88a8` para transportar todas las VLANs de una empresa a través de un proveedor |
| **`IEEE 802.1AX`** | **LACP (Sucesor formal de `802.3ad`)** | L2 | El estándar moderno que mantiene y expande la agregación de enlaces LACP |

---

## 📊 2. Estándares IEEE 802.3 (Ethernet, Velocidades, LACP y PoE)

| Estándar IEEE | Nombre Comercial / Función | Capa | Especificación técnica e interpretación en campo |
|:-------------:|----------------------------|:----:|--------------------------------------------------|
| **`IEEE 802.3u`** | **Fast Ethernet (`100BASE-TX`)** | L1/L2 | `100 Mbps` sobre 2 pares de cobre Cat5+ (pines `1, 2, 3 y 6`) hasta `100 m` |
| **`IEEE 802.3ab`** | **Gigabit Ethernet (`1000BASE-T`)** | L1/L2 | `1 Gbps` sobre **los 4 pares de cobre** Cat5e+ (pines `1 al 8`) hasta `100 m` |
| **`IEEE 802.3z`** | **Gigabit Fibra (`1000BASE-SX / LX`)** | L1/L2 | `1 Gbps` sobre fibra óptica mediante módulos SFP (`SX` 850nm multimodo / `LX` 1310nm monomodo) |
| **`IEEE 802.3ae`** | **10 Gigabit Fibra (`10GBASE-SR / LR / ER`)** | L1/L2 | `10 Gbps` sobre fibra óptica en módulos **SFP+** |
| **`IEEE 802.3an`** | **10 Gigabit Cobre (`10GBASE-T`)** | L1/L2 | `10 Gbps` sobre cobre RJ45 (`55 m` en Cat6 / `100 m` en Cat6A) |
| **`IEEE 802.3bz`** | **Multi-Gigabit (`2.5G / 5GBASE-T`)** | L1/L2 | Permite `2.5 Gbps` y `5 Gbps` sobre el cableado Cat5e/Cat6 ya existente (muy usado en APs WiFi 6/7) |
| **`IEEE 802.3ad`** | **LACP (*Link Aggregation*)** | L2 | 🏆 **Estándar universal para unir varios puertos físicos** (Cisco `EtherChannel`, MikroTik/Linux `Bonding 802.3ad`, Aruba `Trunk LACP`) |
| **`IEEE 802.3x`** | **Flow Control (Tramas `PAUSE`)** | L2 | Permite a un puerto saturado pedirle al vecino que frene unos microsegundos. *(Suele desactivarse en uplinks troncales para no frenar todo el trunk)* |
| **`IEEE 802.3af`** | **PoE (`15.4 W` por puerto)** | L1 | Alimentación activa `44–57V DC` (`12.95 W` útiles): teléfonos VoIP y cámaras IP fijas |
| **`IEEE 802.3at`** | **PoE+ (`30.0 W` por puerto)** | L1 | Alimentación activa `50–57V DC` (`25.5 W` útiles): APs WiFi empresariales y domos PTZ |
| **`IEEE 802.3bt`** | **PoE++ (`60 W` Tipo 3 / `100 W` Tipo 4)** | L1 | Alimentación activa por los 4 pares para equipos de alto consumo |
| **`IEEE 802.3az`** | **EEE (*Energy Efficient Ethernet*)** | L1 | Ahorro de energía en puertos inactivos. ⚠️ **Si un enlace entre marcas distintas sufre microcortes inexplicables, desactivar EEE/Green Ethernet** |

---

## 📊 3. Estándares IEEE 802.11 (WiFi y Roaming Corporativo)

| Estándar IEEE | Nombre Comercial | Bandas de Frecuencia | Anchos de Canal | Qué aporta en producción |
|:-------------:|------------------|:--------------------:|:---------------:|--------------------------|
| **`802.11n`** | **WiFi 4** | `2.4 GHz` y `5 GHz` | `20 / 40 MHz` | Introducción de MIMO. *(En `2.4 GHz` usar siempre ancho de `20 MHz` en canales `1, 6 u 11`)* |
| **`802.11ac`** | **WiFi 5** | Solo `5 GHz` | `20 / 40 / 80 / 160 MHz` | MU-MIMO downlink; estándar maduro para datos en `5 GHz` (`40 MHz` recomendado en oficinas) |
| **`802.11ax`** | **WiFi 6 / WiFi 6E** | `2.4`, `5` y `6 GHz` (6E) | `20 / 40 / 80 / 160 MHz` | **OFDMA** y BSS Coloring: diseñado para **alta densidad de clientes** (oficinas, auditorios) con menor latencia |
| **`802.11be`** | **WiFi 7** | `2.4`, `5` y `6 GHz` | Hasta `320 MHz` | **MLO (*Multi-Link Operation*)**: el cliente transmite por dos bandas simultáneamente |
| **`802.11k`** | **Radio Resource Measurement** | Roaming WiFi | — | El AP le entrega al celular la **lista de APs vecinos cercanos** para que no pierda tiempo escaneando todos los canales a ciegas |
| **`802.11v`** | **BSS Transition Management** | Roaming WiFi | — | Permite al controlador **sugerirle o empujar a un cliente con mala señal** (`-78 dBm`) a que salte a un AP más cercano |
| **`802.11r`** | **Fast BSS Transition (`FT`)** | Roaming WiFi | — | **Roaming en `< 50 ms` sin cortar llamadas VoIP/Teams:** pre-negocia las claves de cifrado con el siguiente AP antes de saltar |
| **`802.11w`** | **PMF (*Protected Management Frames*)** | Seguridad WiFi | — | Cifra las tramas de control para impedir ataques de desconexión forzada (*WiFi Deauth attacks*). Obligatorio en `WPA3` |

---

## 📊 4. RFCs Esenciales de la IETF (Capa 3 a Capa 7)

| Número de RFC | Protocolo / Tecnología | Capa | Por qué lo necesitás en el trabajo diario |
|:-------------:|------------------------|:----:|-------------------------------------------|
| **`RFC 826`** | **ARP** | L2/L3 | Traducción de dirección IP a dirección MAC dentro de una VLAN mediante broadcast |
| **`RFC 791 / 8200`** | **IPv4 (`791`) e IPv6 (`8200`)** | L3 | Estructura del paquete IP, TTL/Hop Limit y direccionamiento global |
| **`RFC 792`** | **ICMP** | L3 | Mensajes de control y diagnóstico (`Echo Request/Reply` del ping, `Time Exceeded` del traceroute y `Fragmentation Needed` de MTU) |
| **`RFC 1191`** | **Path MTU Discovery (PMTUD)** | L3/L4 | Mecanismo por el cual se descubre el MTU menor de una ruta usando el bit `DF=1` e `ICMP Type 3 Code 4` |
| **`RFC 1918`** | **Direcciones IPv4 Privadas** | L3 | Define los bloques internos `10.0.0.0/8`, `172.16.0.0/12` y `192.168.0.0/16` |
| **`RFC 2131 / 3046`** | **DHCP (`2131`) y Option 82 (`3046`)** | L2–L7 | Ciclo DORA de asignación IP y etiqueta de Relay (`GIADDR` / Option 82) |
| **`RFC 2328`** | **OSPFv2** | L3 | Enrutamiento dinámico interno por estado de enlace (algoritmo SPF de Dijkstra, áreas y multicast `224.0.0.5/6`) |
| **`RFC 3021`** | **Prefijos `/31` en enlaces P2P** | L3 | Permite usar subredes de solo 2 IPs (`/31`) en enlaces punto a punto entre routers sin desperdiciar el `.0` y `.3` de un `/30` |
| **`RFC 4271`** | **BGP-4** | L3/L4 | Enrutamiento entre Sistemas Autónomos (`AS`), Internet global, Data Centers Leaf-Spine y multihoming (`TCP 179`) |
| **`RFC 5798`** | **VRRP v3** | L3 | Redundancia abierta de Default Gateway para IPv4 e IPv6 (`224.0.0.18`, protocolo IP `112`, MAC `00:00:5E:00:01:XX`) |
| **`RFC 6598`** | **CGNAT (`100.64.0.0/10`)** | L3/L4 | Bloque reservado para Carrier-Grade NAT en proveedores de Internet |

---

## ⚡ Comandos rápidos de verificación

```text
# Cisco IOS: Verificar estándares activos (802.1Q, 802.1w RSTP, 802.3ad LACP, 802.1AB LLDP)
show interfaces trunk
show spanning-tree summary
show lacp neighbor
show lldp neighbors

# MikroTik RouterOS v7: Verificar 802.1Q, RSTP, 802.3ad y vecinos LLDP
/interface bridge vlan print
/interface bridge monitor bridge1 once
/interface bonding monitor bond1 once
/ip neighbor print
```

---

## 🔗 Ver también

- [`vlans-tagged-untagged-and-trunks`](../concepts/vlans-tagged-untagged-and-trunks.md) — Cómo funciona por dentro el estándar `IEEE 802.1Q`
- [`spanning-tree-and-loop-prevention`](../concepts/spanning-tree-and-loop-prevention.md) — Cómo funciona por dentro el estándar `IEEE 802.1w (RSTP)`
- [`link-aggregation-and-redundancy-l2`](../concepts/link-aggregation-and-redundancy-l2.md) — Cómo funciona por dentro el estándar `IEEE 802.3ad / 802.1AX (LACP)`
