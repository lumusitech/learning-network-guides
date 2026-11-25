⬅️ [Volver a Guías](../README.md)

# Agregación de Enlaces LACP (802.3ad): EtherChannel, Bonding y Trunks — Guía práctica multi-vendor

**Dominio:** `02-switching-l2`
**Nivel:** 🟡 Intermedio
**Estándares:** `IEEE 802.3ad`, `IEEE 802.1AX (LACP)`
**Concepto base:** [`link-aggregation-and-redundancy-l2`](../../concepts/link-aggregation-and-redundancy-l2.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# Cisco IOS: Ver estado de los grupos EtherChannel (flag 'P' = Bundled) y vecinos LACP
show etherchannel summary
show lacp neighbor
show etherchannel load-balance

# MikroTik RouterOS v7: Ver puertos activos en el Bonding y verificar Hardware Offload (H) en el bridge
/interface bonding monitor bond1 once
/interface bridge port print where interface=bond1

# Aruba / HP ProCurve: Ver estado de los grupos LACP (llamados 'Trunks trk1' en Aruba)
show lacp
show trunks

# Linux: Verificar estado de la negociación 802.3ad, Aggregator ID y estado de cada placa esclava
cat /proc/net/bonding/bond0
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

Cuando un único cable de `1 Gbps` o `10 Gbps` entre dos switches (o entre tu switch core y un servidor de virtualización Proxmox / VMware / NAS) se queda chico o representa un punto único de falla física, configurás **LACP (`IEEE 802.3ad / 802.1AX`)**.

Esta guía muestra cómo agrupar **dos puertos físicos (`Puerto 1` y `Puerto 2`)** en una única interfaz lógica (**`Port-channel1` en Cisco, `bond1` en MikroTik, `trk1` en Aruba, `bond0` en Linux**) utilizando el algoritmo de balanceo más eficiente (**`layer-3-and-4` — IP + Puerto TCP/UDP**) y transportando por encima de ese tubo lógico nuestras **VLANs `10, 99, 100 y 200` etiquetadas (`802.1Q`)**.

> **🧠 Recordatorio del modelo mental:** Pensá en LACP como **convertir un puente de 1 carril en una autopista de 2 o 4 carriles con cabina de peaje inteligente (`Hash L3+L4`)**: una vez que agrupás los carriles físicos, **los carriles individuales dejan de existir por separado** y todas las señales de tránsito (las VLANs `802.1Q` y Spanning Tree) se colocan sobre **la autopista entera (`Port-channel1` / `bond1` / `trk1`)**.

---

## 2. 🗺️ Topología de referencia

Uniremos los puertos físicos `1` y `2` de dos equipos (o switch contra servidor Linux) en un enlace agregado LACP activo de `2 × 1 Gbps = 2 Gbps` con transporte Trunk de las VLANs `10, 99, 100, 200`:

```text
+-------------------------------+                        +-------------------------------+
|       EQUIPO A (SW-CORE)      |                        |    EQUIPO B (SW-ACCESO / SRV) |
|                               |   Cable 1 (Pto 1: 1G)  |                               |
|  Interfaz Lógica:             |=======================>|  Interfaz Lógica:             |
|  - Cisco:    Port-channel1    |  LACP 802.3ad (Active) |  - MikroTik: bond1            |
|  - MikroTik: bond1            |  Hash: Layer 3 + 4     |  - Aruba:    trk1             |
|  - Aruba:    trk1             |  Trunk VLANs:          |  - Linux:    bond0            |
|                               |  10, 99, 100, 200      |                               |
|                               |=======================>|                               |
+-------------------------------+   Cable 2 (Pto 2: 1G)  +-------------------------------+
```

| Parámetro del LAG | Valor estándar configurado en los 4 bloques |
|-------------------|---------------------------------------------|
| **Protocolo de negociación** | **`IEEE 802.3ad LACP`** en modo **`Active`** en ambos lados |
| **Puertos físicos miembros** | `Puerto 1` y `Puerto 2` (`Gi1/0/1-2` / `ether1,ether2` / `1-2` / `eth1,eth2`) |
| **Algoritmo de Balanceo (Hash)** | **`Layer 3 + Layer 4`** (`IP Origen/Destino + Puerto TCP/UDP Origen/Destino`) |
| **VLANs transportadas encima** | Trunk `802.1Q` con las VLANs **`10, 99, 100, 200`** (`Tagged`) |

---

## 3. 🛠️ Configuración paso a paso por fabricante

> ⚠️ **Regla de secuencia física para no causar bucles durante el armado:**
>
> 1. **Primero** configurá el grupo LACP en el software de ambos equipos teniendo **solo 1 cable conectado (o ambos puertos apagados)**.
> 2. **Recién cuando ambos lados tengan el LACP creado**, enchufá o encendé el segundo cable.

### A. Cisco IOS / Catalyst (`EtherChannel` / `interface Port-channel1`)

```cisco
configure terminal

! 1. Configurar el algoritmo de balanceo global del switch en Capa 3 + Capa 4 (IP + Puertos TCP/UDP)
port-channel load-balance src-dst-mixed-ip-port

! 2. Agrupar los puertos físicos Gi1/0/1 y Gi1/0/2 usando LACP en modo ACTIVE
interface range GigabitEthernet1/0/1 - 2
 description MIEMBRO_LACP_PO1
 ! Limpiar configuración previa y apagar mientras se agrupa
 shutdown
 channel-protocol lacp
 channel-group 1 mode active
exit

! 3. Configurar el Trunk de VLANs SOBRE LA INTERFAZ LÓGICA Port-channel 1 (¡no en los puertos sueltos!)
interface Port-channel1
 description UPLINK_LACP_SW_ACCESO
 switchport mode trunk
 switchport trunk native vlan 999
 switchport trunk allowed vlan 10,99,100,200
 switchport nonegotiate
exit

! 4. Encender los puertos físicos miembros
interface range GigabitEthernet1/0/1 - 2
 no shutdown
exit

end
write memory
```

### B. MikroTik RouterOS v7 (`/interface bonding` dentro del `bridge1` con Hardware Offload)

> **🚨 Regla de oro en MikroTik:** Para que un switch MikroTik (`CRS3xx / CRS5xx / RB5009`) acelere por hardware (`H`) el LACP junto con tus VLANs, primero debés **quitar a `ether1` y `ether2` de `/interface bridge port`**, crear `bond1` teniéndolos como esclavos (`slaves=ether1,ether2`), y **agregar a `bond1` como puerto dentro de `/interface bridge port` y `/interface bridge vlan`**.

```text
# 1. Si ether1 y ether2 estaban sueltos adentro del bridge1, quitarlos primero del bridge:
/interface bridge port remove [find interface=ether1 or interface=ether2]

# 2. Crear la interfaz lógica 'bond1' con estándar 802.3ad (LACP) y balanceo Layer 3 + 4
/interface bonding
add name=bond1 \
    slaves=ether1,ether2 \
    mode=802.3ad \
    lacp-rate=30secs \
    mii-interval=100ms \
    transmit-hash-policy=layer-3-and-4 \
    comment="UPLINK_LACP_SW_CORE"

# 3. Incorporar a 'bond1' (y NUNCA a ether1/ether2 sueltos!) como puerto Trunk dentro del bridge1:
/interface bridge port
add bridge=bridge1 interface=bond1 frame-types=admit-only-vlan-tagged ingress-filtering=yes comment="TRUNK_LACP_BOND1"

# 4. Asignar las VLANs 10, 99, 100 y 200 como Tagged sobre 'bond1' en la tabla de VLANs del bridge:
/interface bridge vlan
set [find vlan-ids=10]  tagged=bond1
set [find vlan-ids=99]  tagged=bridge1,bond1
set [find vlan-ids=100] tagged=bond1
set [find vlan-ids=200] tagged=bond1
```

### C. Switches Gestionables (Aruba / HP ProCurve — `trunk 1-2 trk1 lacp`)

> **💡 Recordá la trampa de vocabulario de HP/Aruba:** En la consola de Aruba, el comando **`trunk`** crea un grupo **LACP (`trk1`)**, y después a ese `trk1` le asignás las VLANs con la palabra **`tagged`**.

```text
configure

# 1. Elegir algoritmo de balanceo L4 (IP + Puertos TCP/UDP) y unir puertos 1 y 2 en 'trk1' con LACP
trunk-load-balance L4-based
trunk 1-2 trk1 lacp

# 2. Asignar las VLANs 10, 99, 100 y 200 como Tagged sobre la interfaz lógica 'trk1'
vlan 10  tagged trk1
vlan 99  tagged trk1
vlan 100 tagged trk1
vlan 200 tagged trk1

write memory
```

### D. Servidores Linux (`iproute2` / `Netplan` — Servidor Proxmox/KVM conectado por LACP al Switch)

```bash
# 1. Cargar el módulo bonding del kernel y crear 'bond0' en modo 802.3ad con hash layer3+4
sudo modprobe bonding
sudo ip link add name bond0 type bond mode 802.3ad miimon 100 lacp_rate fast xmit_hash_policy layer3+4

# 2. Esclavizar eth1 y eth2 dentro de bond0 (las interfaces esclavas deben estar DOWN al agregarse)
sudo ip link set dev eth1 down && sudo ip link set dev eth1 master bond0
sudo ip link set dev eth2 down && sudo ip link set dev eth2 master bond0
sudo ip link set dev bond0 up

# 3. Crear subinterfaces VLAN 802.1Q encima de bond0 (o meter bond0 en un bridge br0)
sudo ip link add link bond0 name bond0.99 type vlan id 99
sudo ip addr add 10.1.99.20/24 dev bond0.99
sudo ip link set dev bond0.99 up
```

---

## 4. 🔑 Salida clave e interpretación de flags

### En Cisco IOS (`show etherchannel summary`)

```text
SW-CORE# show etherchannel summary
Flags:  D - down        P - bundled in port-channel
        I - stand-alone s - suspended
        H - Hot-standby (LACP only)
        R - Layer3      S - Layer2
        U - in use      f - failed to allocate aggregator

Number of channel-groups in use: 1
Group  Port-channel  Protocol    Ports
------+-------------+-----------+-----------------------------------------------
1      Po1(SU)         LACP      Gi1/0/1(P)  Gi1/0/2(P)
```

### En MikroTik (`/interface bonding monitor bond1 once`)

```text
[netops@SW-ACCESO] > /interface bonding monitor bond1 once
                    mode: 802.3ad
            active-ports: ether1,ether2
          inactive-ports:
          lacp-system-id: D4:CA:6D:11:22:33
     lacp-system-priority: 65535
  lacp-partner-system-id: 00:1A:2B:3C:4D:01
```

### En Linux (`cat /proc/net/bonding/bond0`)

```text
Bonding Mode: IEEE 802.3ad Dynamic link aggregation
Transmit Hash Policy: layer3+4 (1)
MII Status: up
802.3ad info
LACP rate: fast
Active Aggregator Info:
        Aggregator ID: 1
        Number of ports: 2
        Partner Mac Address: 00:1a:2b:3c:4d:01
```

### Tabla de interpretación de columnas y flags

| Columna / Flag | Fabricante | Qué significa realmente | Estado sano vs Estado roto |
|----------------|------------|-------------------------|----------------------------|
| **`Po1(SU)` + `Gi1/0/1(P)`** | Cisco IOS | `S` = Capa 2, `U` = En uso, y **`P` (*Bundled*)** = el puerto negoció LACP con éxito y transmite tráfico | ✅ Ambos puertos deben mostrar `(P)` |
| **`Gi1/0/2(I)` (*Stand-alone*)** | Cisco IOS | El puerto físico tiene link eléctrico, pero **no recibe tramas LACPDU del vecino** | ❌ El otro extremo del cable no tiene LACP configurado en ese puerto |
| **`Gi1/0/2(s)` (*Suspended*)** | Cisco IOS | LACP detectó que ese puerto tiene distinta velocidad, duplex o VLANs que `Gi1/0/1` | ❌ Igualar configuración de velocidad/duplex/switchport en ambos puertos |
| **`lacp-partner-system-id`** | MikroTik / Linux | Es la dirección MAC base del switch vecino que respondió al saludo LACP | ✅ Si ves la MAC del switch vecino y `active-ports: ether1,ether2`, el LACP está 100% operativo |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: En un Switch MikroTik CRS3xx armaste `bond1`, el enlace funciona, pero la CPU del switch se clava al 100% cuando pasa tráfico entre VLANs

1. **Verificación rápida:** `/interface bridge port print where interface=bond1`
2. **Qué buscar en la salida:** Fijate si la fila de `bond1` tiene la letra **`H` (*HW-OFFLOAD*)** a la izquierda.
3. **Causa raíz y corrección:**
   - Los chips de switch de MikroTik (`CRS3xx / CRS5xx`) **solo soportan Hardware Offload (`H`) en modos `802.3ad` (LACP) y `balance-xor`**.
   - Si por error configuraste `mode=balance-rr` (*Round-Robin*), el chip ASIC no puede acelerarlo y manda todos los paquetes a la CPU del switch. Cambialo a **`mode=802.3ad`** y verificá que aparezca inmediatamente la `H`.

### Síntoma 2: Un puerto del LACP se cae y levanta cada 30 segundos en un enlace entre Linux y un Switch

1. **Causa raíz:** Discrepancia extrema o pérdida de paquetes de control por `lacp-rate` (`fast = 1s` vs `slow = 30s`) en un servidor con la CPU saturada que demora en responder LACPDUs.
2. **Corrección:** Asegurar el mismo `lacp-rate` (`30secs / slow` o `1sec / fast`) en ambos extremos del enlace.

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **Cómo agregar un tercer cable (`ether3` / `Gi1/0/3`) a un LACP en caliente sin cortar el tráfico:**
  - Con el tercer cable todavía desconectado (o el puerto en `shutdown`), agregalo a la lista `slaves=ether1,ether2,ether3` en MikroTik y ejecutá `channel-group 1 mode active` en `Gi1/0/3` del Cisco (copiando exactamente la misma configuración de `Port-channel1` al puerto `Gi1/0/3`).
  - Recién entonces encendé el puerto (`no shutdown`): LACP negociará el tercer carril en caliente sin perder un solo paquete de los dos carriles que ya estaban activos.

---

## 7. ⚠️ Errores comunes en producción

- **❌ Modificar una VLAN en `Gi1/0/1` en lugar de modificarla en `interface Port-channel1` en Cisco:** Si entrás a `interface Gi1/0/1` y cambiás las VLANs permitidas ahí adentro, `Gi1/0/1` deja de coincidir con `Gi1/0/2` y con `Port-channel1`: Cisco **suspende inmediatamente `Gi1/0/1` (`flag s`)** para evitar inconsistencias. En Cisco, **todo cambio de VLANs se hace única y exclusivamente dentro de `interface Port-channel1`** (el cual replica el cambio automáticamente a todos sus puertos físicos miembros).
- **❌ En MikroTik, olvidar actualizar `/interface bridge vlan` cuando reemplazás `ether1` por `bond1`:** Si antes tus VLANs decían `tagged=ether1` y creaste `bond1`, tenés que cambiar `tagged=ether1` por **`tagged=bond1`** en todas las filas de `/interface bridge vlan`.

---

## 8. ✅ Buenas prácticas profesionales

- **Configurar siempre `transmit-hash-policy=layer-3-and-4` (`src-dst-mixed-ip-port`):** Es la única política que reparte equitativamente el tráfico tanto cuando las conexiones pasan a través de un router como cuando un mismo servidor abre múltiples flujos TCP hacia otro servidor.
- **Usar puertos de distintas placas o distintos ASICs cuando el chasis lo permita:** En un stack de switches o un router modular, poné el Cable 1 en el Switch 1 del stack y el Cable 2 en el Switch 2 del stack (*Cross-Stack EtherChannel / MLAG*) para sobrevivir incluso a la muerte completa de uno de los switches.

---

## 9. 🔗 Referencias internas

- [`link-aggregation-and-redundancy-l2`](../../concepts/link-aggregation-and-redundancy-l2.md) — El modelo mental del algoritmo de Hash y por qué un solo flujo TCP no supera la velocidad de 1 cable individual
- [`vlans-8021q-access-trunk-pvid`](vlans-8021q-access-trunk-pvid.md) — Cómo configurar las VLANs que viajan por encima del grupo LACP
- [`spanning-tree-rstp-bpduguard`](spanning-tree-rstp-bpduguard.md) — Cómo ve Spanning Tree a la interfaz `Port-channel1 / bond1 / trk1`
