⬅️ [Volver a Guías](../README.md)

# MikroTik Bridge VLAN Filtering y Hardware Offloading (`H`) — Guía profunda de arquitectura

**Dominio:** `06-mikrotik`
**Nivel:** 🔴 Avanzado
**Estándares:** `IEEE 802.1Q`, `Switch Chip ASIC Offloading`, `L3HW (Layer 3 Hardware Offloading)`
**Concepto base:** [`vlans-tagged-untagged-and-trunks`](../../concepts/vlans-tagged-untagged-and-trunks.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# MikroTik RouterOS v7: Verificar qué chip de switch tiene el equipo y si los puertos tienen Hardware Offload (H)
/interface ethernet switch print
/interface bridge port print
/interface bridge vlan print
/system resource print
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

El sistema **`Bridge VLAN Filtering`** de MikroTik RouterOS es extraordinariamente potente, pero tiene una particularidad arquitectónica que desconcierta incluso a técnicos con años de experiencia en Cisco: **en MikroTik, la interfaz `bridge1` cumple DOS roles completamente diferentes al mismo tiempo**:

1. **Es el Switch Virtual (el plano que agrupa los puertos físicos `ether1..ether24`).**
2. **Es el Puerto Interno hacia la CPU del propio MikroTik (`CPU Port`).**

Si no entendés cuándo tenés que poner a **`bridge1` adentro de la lista `tagged=...`** y cuándo **NO** tenés que ponerlo, o bien te quedás sin acceso al equipo al activar `vlan-filtering=yes`, o bien hacés que todo el tráfico de un switch de 24 puertos suba innecesariamente a la pequeña CPU del switch saturándola al `100%`.

> **🧠 Recordatorio del modelo mental:** Pensá en un equipo MikroTik como **un edificio que en la Planta Baja tiene una autopista rápida de hardware (el Switch Chip ASIC) y en el Piso Superior tiene una oficina administrativa (la CPU de RouterOS)** conectados por **un único ascensor interno que se llama `bridge1`**:
>
> - Si una VLAN solo tiene que entrar por el puerto 1 y salir por el puerto 2 (**el equipo actúa solo como Switch Capa 2 para esa VLAN**), **NO pongas a `bridge1` en `tagged=`** (los camiones pasan directo por la autopista de abajo sin subir al ascensor de la CPU).
> - Si querés que el propio MikroTik **tenga una dirección IP, entregue DHCP o enrute esa VLAN en Capa 3**, entonces esa VLAN **sí tiene que subir por el ascensor a la CPU**, por lo que **ES OBLIGATORIO incluir a `bridge1` en `tagged=bridge1,...`** y crearle su `/interface vlan` sobre `bridge1`.

---

## 2. 🗺️ Topología de referencia (El Diagrama Interno que lo explica todo)

Mirá cómo se conectan por dentro los puertos físicos, el **Switch Chip (ASIC)** y la **CPU de RouterOS** a través del puerto interno `bridge1`:

```text
+-------------------------------------------------------------------------------+
|                     ADENTRO DE TU EQUIPO MIKROTIK                             |
|                                                                               |
|   +-----------------------------------------------------------------------+   |
|   |                   PLANO DE CONTROL / CAPA 3 (CPU)                     |   |
|   |   /interface vlan:  [vlan10 (10.1.10.1)]     [vlan99 (10.1.99.2)]     |   |
|   |   (DHCP, Firewall, Routing L3, SSH/WinBox)                            |   |
|   +-----------------------------------+-----------------------------------+   |
|                                       ||                                      |
|                                       ||  <-- ¡El "Ascensor" interno a la CPU |
|                                       ||      se llama 'bridge1' en la tabla  |
|                                       ||      /interface bridge vlan!         |
|                                       v                                       |
|   +-----------------------------------------------------------------------+   |
|   |             SWITCH CHIP (ASIC de Hardware — Flag 'H')                 |   |
|   |   Conmuta a velocidad de cable (Wire-Speed 1G / 10G / 25G / 100G)     |   |
|   +---------+-------------------+-------------------+---------------------+   |
|             |                   |                   |                         |
|         (ether1)            (ether2)            (ether3)                      |
+-------------+-------------------+-------------------+-------------------------+
              ||                  |                   |
      Trunk (10,20,99)      Access VLAN 10      Access VLAN 20
```

### Tabla de Familias de Hardware MikroTik y su Soporte de Chip

| Familia de Equipos MikroTik | Chip de Switch Interno | ¿Soporta `Bridge VLAN Filtering` en Hardware (`H`)? | Uso ideal |
|-----------------------------|------------------------|:---------------------------------------------------:|-----------|
| **`CRS3xx` y `CRS5xx`** (`CRS326`, `CRS328`, `CRS354`, `CRS504`, `CRS518`) | Marvell Prestera (`98DXxxxx`) | 🏆 **SÍ, 100% en Hardware (`H`)** + LACP en HW + **L3HW Offloading** (enruta en el chip!) | Switches Core, Distribución y Acceso profesionales |
| **`RB5009`, `RB4011`, `CCR2116`, `CCR2216`** | Marvell Amethyst (`88E6393X`) / Prestera | 🏆 **SÍ, 100% en Hardware (`H`)** en todos los puertos del chip | Routers de borde de alto rendimiento con switching integrado |
| **`CCR2004-16G-2S+`** | Sin switch chip dedicado (puertos directos a CPU ARM64 potente) | Conmuta en su CPU de 4 núcleos de alta velocidad | Router puro de borde / BGP / VPN / Firewall |
| **Modelos antiguos `CRS1xx / CRS2xx` o `RB2011 / RB3011` (`QCA8337`)** | Qualcomm Atheros viejo | ⚠️ En estos chips antiguos de hace 10 años, activar `vlan-filtering=yes` en el bridge apaga el flag `H` y pasa por CPU | En hardware nuevo usar siempre `CRS3xx+` o `RB5009` |

---

## 3. 🛠️ Configuración paso a paso: Los 2 Roles de un MikroTik

### Caso A: MikroTik actuando SOLO como Switch Capa 2 (`SW-ACCESO` en `10.1.99.2`)

En un **Switch de Acceso**, el equipo **NO enruta** las VLANs 10, 20 ni 100 (su Default Gateway está arriba en el Router). El switch solo necesita hablar con su propia CPU en la **`VLAN 99` (Management)** para que vos entres por SSH/WinBox.

Observá cómo **`bridge1` SOLO se incluye en la fila de la `VLAN 99`** y **NO** en las VLANs `10, 20 y 100` (así el tráfico de usuarios jamás molesta a la CPU del switch):

```text
# 1. Crear el único bridge del switch
/interface bridge
add name=bridge1 protocol-mode=rstp priority=0x8000 vlan-filtering=no

# 2. Configurar PVID y seguridad de entrada en cada boca física (/interface bridge port)
/interface bridge port
# Puerto 1: Trunk que sube al Router
add bridge=bridge1 interface=ether1 frame-types=admit-only-vlan-tagged ingress-filtering=yes trusted=yes
# Puertos 2 y 3: Usuarios en VLAN 10
add bridge=bridge1 interface=ether2 pvid=10 frame-types=admit-only-untagged-and-priority-tagged ingress-filtering=yes edge=yes bpdu-guard=yes
add bridge=bridge1 interface=ether3 pvid=10 frame-types=admit-only-untagged-and-priority-tagged ingress-filtering=yes edge=yes bpdu-guard=yes
# Puerto 4: Servidor en VLAN 20
add bridge=bridge1 interface=ether4 pvid=20 frame-types=admit-only-untagged-and-priority-tagged ingress-filtering=yes edge=yes bpdu-guard=yes

# 3. Configurar la tabla de VLANs del chip (/interface bridge vlan)
#    ¡MIRÁ EL DETALLE DE 'bridge1': solo está en la VLAN 99!
/interface bridge vlan
add bridge=bridge1 vlan-ids=10 tagged=ether1         untagged=ether2,ether3 comment="Pasa 100% por chip ASIC sin tocar CPU"
add bridge=bridge1 vlan-ids=20 tagged=ether1         untagged=ether4        comment="Pasa 100% por chip ASIC sin tocar CPU"
add bridge=bridge1 vlan-ids=99 tagged=bridge1,ether1                        comment="¡Sube a la CPU (bridge1) para SSH/WinBox!"

# 4. Crear la única interfaz VLAN de Capa 3 para administrar el switch
/interface vlan
add interface=bridge1 name=vlan99-mgmt vlan-id=99
/ip address
add address=10.1.99.2/24 interface=vlan99-mgmt
/ip route
add dst-address=0.0.0.0/0 gateway=10.1.99.1

# 5. Activar el filtrado en el chip
/interface bridge set bridge1 vlan-filtering=yes
```

---

### Caso B: MikroTik actuando como Router + Switch (`RTR-BORDE` que es Gateway de todas las VLANs)

Si el equipo es el **Router principal** que tiene las IPs `10.1.10.1`, `10.1.20.1` y `10.1.99.1`, entrega DHCP y enruta entre ellas, entonces **TODAS las VLANs necesitan subir por el ascensor `bridge1` hacia la CPU**:

```text
# En un Router que enruta las VLANs 10, 20 y 99, 'bridge1' VA EN TODAS como tagged:
/interface bridge vlan
add bridge=bridge1 vlan-ids=10 tagged=bridge1,ether1 untagged=ether2,ether3
add bridge=bridge1 vlan-ids=20 tagged=bridge1,ether1 untagged=ether4
add bridge=bridge1 vlan-ids=99 tagged=bridge1,ether1

/interface vlan
add interface=bridge1 name=vlan10-staff   vlan-id=10
add interface=bridge1 name=vlan20-servers vlan-id=20
add interface=bridge1 name=vlan99-mgmt    vlan-id=99
```

---

### Caso C: Activar Enrutamiento Capa 3 en el Chip ASIC (*L3 Hardware Offloading — L3HW*) en Switches `CRS3xx / CRS5xx`

En switches MikroTik `CRS317`, `CRS326-24S+2Q+`, `CRS354` o `CRS5xx`, si querés que el propio switch haga **Inter-VLAN Routing a `10 Gbps / 40 Gbps / 100 Gbps` en el chip ASIC** sin usar la CPU de 800 MHz del switch:

```text
# 1. Configurar las interfaces /interface vlan y sus IPs como en el Caso B.
# 2. Encender L3 Hardware Offloading en el chip de switch y en los puertos internos:
/interface ethernet switch set switch1 l3-hw-offloading=yes
# (Si tenés un puerto WAN hacia Internet donde necesitás NAT/Firewall por CPU,
#  desactivás l3-hw-offloading SOLO en ese puerto WAN para que Internet pase por CPU
#  mientras el enrutamiento interno entre VLANs vuela por el chip ASIC!):
/interface ethernet switch port set ether1-wan l3-hw-offloading=no
```

---

## 4. 🔑 Salida clave e interpretación de flags

### Verificación de `CURRENT-TAGGED` y `CURRENT-UNTAGGED` (`/interface bridge vlan print`)

```text
[netops@SW-ACCESO] > /interface bridge vlan print
Flags: D - DYNAMIC
Columns: BRIDGE, VLAN-IDS, CURRENT-TAGGED, CURRENT-UNTAGGED
#   BRIDGE   VLAN-IDS  CURRENT-TAGGED  CURRENT-UNTAGGED
;;; Pasa 100% por chip ASIC sin tocar CPU
0   bridge1        10  ether1          ether2
                                       ether3
;;; ¡Sube a la CPU (bridge1) para SSH/WinBox!
1   bridge1        99  bridge1
                       ether1
2 D bridge1         1                  bridge1
                                       ether1
```

### Tabla de interpretación de columnas y flags

| Indicador en la salida | Qué significa realmente | Diagnóstico inmediato |
|------------------------|-------------------------|-----------------------|
| **`bridge1` figura dentro de `CURRENT-TAGGED`** | El "ascensor" hacia la CPU del MikroTik está abierto para esa VLAN | ✅ **Obligatorio** si tenés una `/interface vlan` con ese `vlan-id` sobre `bridge1`. Si falta `bridge1` acá, tu `/interface vlan` quedará sorda y muda |
| **Fila con flag `D` (*Dynamic*) para `VLAN-IDS: 1`** | RouterOS agrega dinámicamente como `untagged` a todo puerto que tenga `pvid=1` | Es normal en puertos Trunk cuyo `pvid` quedó en `1` (si el puerto tiene `frame-types=admit-only-vlan-tagged`, esa fila dinámica `1` es ignorada en la entrada) |
| **Flag `H` en `/interface bridge port print`** | El puerto está acelerado en el chip ASIC del switch | Si un puerto no tiene la letra `H`, su tráfico está pasando por la CPU principal |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: Creaste `/interface vlan add interface=bridge1 name=vlan10 vlan-id=10`, le pusiste IP `10.1.10.1/24`, pero ninguna PC de la VLAN 10 llega por ping a `10.1.10.1`

1. **Verificación rápida:** `/interface bridge vlan print where vlan-ids=10`
2. **Qué buscar en la salida:** Mirá la columna `CURRENT-TAGGED`. Aparece `ether1`, pero **NO aparece `bridge1`**.
3. **Causa raíz:** Las tramas de la VLAN 10 entran al chip del switch, pero nunca les diste permiso de subir por el puerto interno `bridge1` hacia la CPU donde vive la interfaz `vlan10`.
4. **Corrección en 1 comando:**
   `/interface bridge vlan set [find vlan-ids=10] tagged=bridge1,ether1` → Instantáneamente el ping a `10.1.10.1` empieza a responder.

### Síntoma 2: Pusiste una dirección IP directamente sobre `ether2` (`/ip address add address=10.1.10.1/24 interface=ether2`), pero `ether2` está adentro de `bridge1`

1. **Verificación rápida:** `/ip address print` (la fila aparece con flag **`I` — Invalid** o el DHCP server sobre `ether2` aparece en rojo inválido).
2. **Regla inquebrantable de RouterOS:** Cuando un puerto físico (`ether2`) es miembro (*slave*) de un bridge (`bridge1`), **jamás se le asigna una IP ni un servidor DHCP a `ether2`**. Toda IP o DHCP va sobre la interfaz **`vlanX`** (si usás VLANs) o sobre el maestro **`bridge1`**.

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **Cómo agregar una VLAN nueva (`VLAN 50`) a un Trunk en MikroTik sin cortar las VLANs existentes:**
  1. Agregar la fila en la tabla del chip: `/interface bridge vlan add bridge=bridge1 vlan-ids=50 tagged=bridge1,ether1`.
  2. Si hay bocas de acceso para esa VLAN, cambiarles su PVID: `/interface bridge port set [find interface=ether6] pvid=50 frame-types=admit-only-untagged-and-priority-tagged`.
  - *(Nota: En RouterOS v7 ni siquiera hace falta escribir `untagged=ether6` en `/interface bridge vlan`, porque RouterOS lee que `ether6` tiene `pvid=50` y lo agrega dinámicamente a `CURRENT-UNTAGGED` de la VLAN 50).*

---

## 7. ⚠️ Errores comunes en producción

- **❌ Crear `/interface vlan` colgando de un puerto físico (`interface=ether1`) cuando `ether1` ya forma parte de `bridge1`:** Si `ether1` está adentro de `bridge1`, **todas las interfaces `/interface vlan` deben colgar de `interface=bridge1`**, nunca de `interface=ether1`. Colgar una VLAN de un puerto esclavo rompe el Hardware Offloading y el aprendizaje de MACs del bridge.
- **❌ Agrupar varias VLANs en una misma línea (`vlan-ids=10,20,30`) y luego querer poner un puerto `untagged` en una sola de ellas:** Aunque RouterOS te permite escribir `vlan-ids=10,20,30 tagged=ether1` en una sola fila para ahorrar líneas en trunks puros, **es mucho más limpio, legible y fácil de mantener crear 1 fila por cada VLAN individual** (`vlan-ids=10`, `vlan-ids=20`, `vlan-ids=30`).

---

## 8. ✅ Buenas prácticas profesionales

- **Usar siempre `ingress-filtering=yes` y `frame-types=` explícito en cada puerto de `/interface bridge port`:**
  - En Trunks puros: `frame-types=admit-only-vlan-tagged`.
  - En Puertos Access: `frame-types=admit-only-untagged-and-priority-tagged`.
  - En Puertos Híbridos (APs): `frame-types=admit-all`.
- **Verificar siempre la letra `H` después de cualquier cambio en el bridge:** Ejecutá `/interface bridge port print` y confirmá que todos los puertos activos conserven su `H` de aceleración por hardware.

---

## 9. 🔗 Referencias internas

- [`vlans-8021q-access-trunk-pvid`](../02-switching-l2/vlans-8021q-access-trunk-pvid.md) — Comparación lado a lado de esta configuración de MikroTik contra Cisco IOS, Aruba y Linux
- [`routeros-v7-first-setup-and-hardening`](routeros-v7-first-setup-and-hardening.md) — Cómo integrar este bridge dentro de la configuración completa y segura de un router MikroTik
- [`vlans-tagged-untagged-and-trunks`](../../concepts/vlans-tagged-untagged-and-trunks.md) — El modelo mental teórico de Ingress (`PVID`) y Egress (`Tagged/Untagged`)
