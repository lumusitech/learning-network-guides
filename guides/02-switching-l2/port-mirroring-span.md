⬅️ [Volver a Guías](../README.md)

# Port Mirroring (SPAN) — Copia de tráfico en switches para análisis con Wireshark / IDS

**Dominio:** `02-switching-l2`
**Nivel:** 🟢 Básico
**Estándares:** `Cisco SPAN / RSPAN`, `Switch Chip Mirroring`, `Linux tc mirred`
**Concepto base:** [`ethernet-mac-and-arp`](../../concepts/ethernet-mac-and-arp.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# Cisco IOS: Ver sesiones de Port Mirroring (SPAN) activas en el switch
show monitor session all

# MikroTik RouterOS v7 (Switch Chip CRS3xx/RB): Ver configuración de mirror-source y mirror-target
/interface ethernet switch print
/interface ethernet switch port print

# Aruba / HP ProCurve: Ver sesiones de monitor de puertos activas
show monitor

# Linux (En el host que recibe el espejo en su placa eth1): Verificar paquetes recibidos en modo promiscuo
sudo tcpdump -ni eth1 -e -c 20
```

---

## 📑 Índice

1. [¿Qué resuelve y cuándo usarlo?](#1--qué-resuelve-y-cuándo-usarlo)
2. [Topología de referencia](#2-️-topología-de-referencia)
3. [Configuración paso a paso por fabricante](#3-️-configuración-paso-a-paso-por-fabricante)
4. [Salida clave e interpretación de flags](#4--salida-clave-e-interpretación-de-flags)
5. [Uso en troubleshooting](#5--uso-en-troubleshooting)
6. [Mantenimiento, backup y rollback seguro](#6-️-mantenimiento-backup-y-rollback-seguro)
7. [Errores comunes en producción](#7-️-errores-comunes-en-producción)
8. [Buenas prácticas profesionales](#8--buenas-prácticas-profesionales)
9. [Referencias internas](#9--referencias-internas)

---

## 1. 🧠 ¿Qué resuelve y cuándo usarlo?

Como vimos en [`ethernet-mac-and-arp.md`](../../concepts/ethernet-mac-and-arp.md), un switch aprende en qué puerto está cada dirección MAC y envía los paquetes Unicast **exclusivamente** al puerto del destinatario. Por eso, si conectás tu laptop con **Wireshark** en el puerto 24 del switch esperando ver qué habla el teléfono IP o el servidor del puerto 2, **no vas a ver absolutamente nada** (solo verás broadcasts ARP/DHCP).

El **Port Mirroring** (llamado **SPAN — *Switched Port Analyzer*** en Cisco) le ordena al chip ASIC de hardware del switch: **"Cloná en tiempo real cada trama que entre (`RX`) y salga (`TX`) por el Puerto Origen (`Puerto 2`) y sacá una fotocopia idéntica por el Puerto Destino (`Puerto 24`)"**. Así podés analizar con Wireshark un dispositivo cerrado (una cámara IP, un teléfono VoIP, un PLC industrial o un enlace Trunk) o alimentar permanentemente un sensor **IDS (Suricata / Zeek)** sin consumir CPU del switch ni interrumpir el servicio.

> **🧠 Recordatorio del modelo mental:** Pensá en el Port Mirroring como **conectar un auricular espía en paralelo en la central telefónica**: la conversación original entre los dos internos sigue fluyendo a velocidad de hardware sin enterarse, mientras una copia exacta del audio sale hacia tu grabador en el puerto de monitoreo.

---

## 2. 🗺️ Topología de referencia

En todos los fabricantes copiaremos todo el tráfico entrante y saliente (`both = RX + TX`) del **Puerto 2 (`Origen`)** hacia el **Puerto 24 (`Destino`)**, donde está conectada nuestra laptop con Wireshark o un sensor Suricata:

```text
                       [RTR-BORDE]
                            || (Puerto 1: Trunk)
                            v
             +------------------------------+
             |          SW-ACCESO           |
             |                              |
             |  Puerto 2 ----(Fotocopia)--->|---> Puerto 24 (Mirror Target / Destination)
             |  (Source)      en chip ASIC  |             |
             +------------------------------+             v
                    |                             [Laptop con Wireshark / IDS]
                    v                             (Placa en modo promiscuo, sin IP)
         [Teléfono VoIP / Servidor]
           (Tráfico a inspeccionar)
```

| Rol en el Espejo | Nombre en Cisco | Nombre en MikroTik | Nombre en Aruba | Puerto en el ejemplo |
|------------------|-----------------|--------------------|-----------------|:--------------------:|
| **Puerto a espiar (Origen)** | `monitor session 1 source` | `mirror-source` | `monitor all both` | **Puerto 2** (`Gi1/0/2` / `ether2`) |
| **Puerto del analizador (Destino)** | `monitor session 1 destination` | `mirror-target` | `mirror-port` | **Puerto 24** (`Gi1/0/24` / `ether24`) |

---

## 3. 🛠️ Configuración paso a paso por fabricante

### A. Cisco IOS / Catalyst (`SPAN`)

```cisco
configure terminal

! 1. Limpiar cualquier sesión previa y definir el Puerto 2 como Origen (both = RX y TX)
no monitor session 1
monitor session 1 source interface GigabitEthernet1/0/2 both

!    (Alternativa: Si querés espejar TODA una VLAN completa en vez de un solo puerto físico):
!    monitor session 1 source vlan 30 both

! 2. Definir el Puerto 24 como Destino donde está conectada tu laptop con Wireshark
!    *(Si querés que el switch conserve las etiquetas VLAN 802.1Q originales al sacar la copia,
!      agregá al final 'encapsulation replicate')*
monitor session 1 destination interface GigabitEthernet1/0/24 encapsulation replicate

end
```

> **⚠️ Importante en Cisco:** Mientras un puerto (`Gi1/0/24`) actúa como `destination` de una sesión SPAN, **ese puerto queda en modo "solo salida de copias"** y no puede usarse para navegar ni entrar por SSH al switch (a menos que agregues explícitamente la palabra clave `ingress` al final, lo cual no se recomienda para no inyectar tráfico accidental desde la laptop).

### B. MikroTik RouterOS v7 (Espejado en el Chip de Switch a velocidad de cable, `0%` CPU)

```text
# 1. Ver cómo se llama el chip de switch interno de tu equipo (normalmente 'switch1')
/interface ethernet switch print

# 2. En switches modernos CRS3xx / CRS5xx y routers con chip Marvell (RB5009 / RB4011):
#    Definir el puerto destino (mirror-target) a nivel del chip y activar el origen en el puerto a espiar:
/interface ethernet switch set switch1 mirror-target=ether24
/interface ethernet switch port set ether2 mirror-ingress=yes mirror-egress=yes

#    *(Nota para modelos donde se define directo en /interface ethernet switch)*:
#    /interface ethernet switch set switch1 mirror-source=ether2 mirror-target=ether24
```

### C. Switches Gestionables (Aruba / Ubiquiti / TP-Link)

```text
# En Aruba ProCurve / AOS-S:
configure
# 1. Definir el puerto 24 como destino del espejo
mirror-port 24
# 2. Entrar al puerto 2 (o rango de puertos) y activar el envío de copia (both = Rx y Tx)
interface 2
   monitor all both
   exit
```

### D. Linux (En la laptop o servidor IDS que recibe el tráfico en `eth1`, y cómo espejar un puerto Linux con `tc`)

```bash
# 1. En el servidor IDS / Laptop que RECIBE el espejo en su placa secundaria 'eth1':
#    Levantar la placa en modo promiscuo sin asignarle IP (para que sea 100% invisible y pasiva)
#    y desactivar GRO/LRO para ver los tamaños reales de paquete en el cable:
sudo ip link set dev eth1 up promisc on
sudo ethtool -K eth1 gro off lro off
sudo tcpdump -ni eth1 -e

# 2. (Extra) Si tu switch es un Bridge Linux (ej. un nodo Proxmox) y querés espejar 'eth2' hacia 'eth24'
#    usando Traffic Control (tc mirred) del kernel Linux:
sudo tc qdisc add dev eth2 handle ffff: ingress
sudo tc filter add dev eth2 parent ffff: protocol all u32 match u32 0 0 action mirred egress mirror dev eth24
sudo tc qdisc add dev eth2 handle 1: root prio
sudo tc filter add dev eth2 parent 1: protocol all u32 match u32 0 0 action mirred egress mirror dev eth24
```

---

## 4. 🔑 Salida clave e interpretación de flags

### En Cisco IOS (`show monitor session 1`)

```text
SW-ACCESO# show monitor session 1
Session 1
---------
Type                   : Local Session
Source Ports           :
    Both               : Gi1/0/2
Destination Ports      : Gi1/0/24
    Encapsulation      : Replicate
          Ingress      : Disabled
```

### En MikroTik (`/interface ethernet switch port print`)

```text
[netops@SW-ACCESO] > /interface ethernet switch port print where name=ether2 or name=ether24
Columns: NAME, SWITCH, MIRROR-INGRESS, MIRROR-EGRESS
# NAME     SWITCH   MIRROR-INGRESS  MIRROR-EGRESS
1 ether2   switch1  yes             yes
23 ether24 switch1  no              no
```

### Tabla de interpretación de salidas

| Parámetro / Salida | Fabricante | Qué significa realmente | Por qué prestarle atención |
|--------------------|------------|-------------------------|----------------------------|
| **`Both : Gi1/0/2`** (`mirror-ingress=yes` + `egress=yes`) | Cisco / MikroTik | Se están copiando tanto los paquetes que **entran** como los que **salen** del Puerto 2 | Si solo activaras `rx` (`ingress`), verías las preguntas que hace el equipo pero no las respuestas que recibe |
| **`Encapsulation : Replicate`** vs `Native` | Cisco IOS | `Replicate`: saca las tramas hacia Wireshark **conservando el tag VLAN `802.1Q` original**. `Native`: les quita el tag antes de sacarlas | Al espiar un puerto **Trunk**, siempre usá `encapsulation replicate` para poder ver en Wireshark qué VLAN trae cada paquete |
| **`Ingress : Disabled`** | Cisco IOS | El puerto 24 (donde está tu laptop) tiene bloqueada la entrada de paquetes hacia la red | ✅ Medida de seguridad para que tu laptop de captura no pueda inyectar paquetes ni causar bucles en la red espiada |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: En Wireshark sobre Windows no ves las etiquetas VLAN (`802.1Q`) aunque el switch las está enviando

1. **Causa raíz:** Muchos drivers de placas de red Ethernet en Windows (Intel / Realtek) **arrancan la etiqueta `802.1Q` en hardware antes de pasarle la trama a Wireshark** a menos que modifiques una clave del Registro de Windows (`MonitorModeEnabled` / `PriorityVLANTag`).
2. **Solución profesional:** Para diagnosticar VLANs con certeza absoluta, capturá desde **Linux (`tcpdump -ni eth1 -e`)** o usá `/tool sniffer` en MikroTik con streaming **TZSP (`UDP 37008`)** hacia tu Wireshark: como TZSP envuelve la trama original adentro de un paquete UDP, Windows no puede tocar la etiqueta VLAN interna y Wireshark te muestra el tag `802.1Q` intacto en cualquier sistema operativo.

### Síntoma 2: En Wireshark ves que todos los paquetes aparecen duplicados (dos copias de cada `SYN`, dos copias de cada `ICMP`)

1. **Causa raíz:** Configuraste el espejo sobre **toda una VLAN (`source vlan 10 both`)** o sobre **dos puertos a la vez**, y el paquete entró por el puerto A de la VLAN 10 (se hizo 1 copia en `RX`) y salió por el puerto B de la misma VLAN 10 (se hizo una 2da copia idéntica en `TX`).
2. **Corrección:** Al espejar una VLAN completa o varios puertos del mismo switch, espejá **únicamente `rx` (`mirror-ingress=yes` / `source vlan 10 rx`)** para capturar una sola vez cada paquete al entrar al switch.

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **Desactivar la sesión de Port Mirroring al terminar el diagnóstico:**
  - En Cisco: `configure terminal` → `no monitor session 1`.
  - En MikroTik: `/interface ethernet switch port set ether2 mirror-ingress=no mirror-egress=no` y `/interface ethernet switch set switch1 mirror-target=none`.
  - En Aruba: `no interface 2 monitor`.

---

## 7. ⚠️ Errores comunes en producción

- **❌ Espejar 4 puertos de `1 Gbps` (`RX + TX`) hacia un único puerto destino de `1 Gbps` (*Oversubscription*):** Si los 4 puertos espiados están moviendo `400 Mbps` cada uno (`1.6 Gbps` en total), en el puerto destino de `1 Gbps` simplemente no entran: el switch descartará el exceso de paquetes copiados y en Wireshark verás falsas "pérdidas de paquetes" que en la red real no ocurrieron.
- **❌ Configurar como `destination / mirror-target` el puerto por el cual vos mismo estás conectado por SSH al switch:** Apenas des `Enter`, el switch convertirá tu puerto en una boca de "solo salida de copias SPAN", **cortará tu conexión normal de red y te quedarás afuera del switch**.

---

## 8. ✅ Buenas prácticas profesionales

- **Dejar reservado el último puerto del switch core (ej. `Puerto 24` o `Puerto 48`) para un sensor IDS o diagnóstico:** Documentarlo con `description SPAN_PORT_IDS_WIRESHARK`.
- **Para diagnósticos remotos rápidos sin ir con una laptop al rack:** Recordá que con [`packet-capture-tcpdump-sniffer-epc.md`](../01-fundamentals/packet-capture-tcpdump-sniffer-epc.md) podés capturar directamente en el router por SSH o enviarte el stream TZSP por red sin necesitar una segunda placa física.

---

## 9. 🔗 Referencias internas

- [`packet-capture-tcpdump-sniffer-epc`](../01-fundamentals/packet-capture-tcpdump-sniffer-epc.md) — Cómo analizar con `tcpdump` y Wireshark el tráfico recibido en el puerto espejo
- [`ethernet-mac-and-arp`](../../concepts/ethernet-mac-and-arp.md) — Por qué la tabla CAM del switch aísla el tráfico Unicast y hace necesario el Port Mirroring
- [`vlans-8021q-access-trunk-pvid`](vlans-8021q-access-trunk-pvid.md) — Cómo preservar las etiquetas `802.1Q` al espejar enlaces Trunk
