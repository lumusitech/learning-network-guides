⬅️ [Volver a Guías](../README.md)

# Spanning Tree (RSTP 802.1w), Root Bridge y BPDU Guard — Guía práctica multi-vendor

**Dominio:** `02-switching-l2`
**Nivel:** 🟡 Intermedio
**Estándares:** `IEEE 802.1w (RSTP)`, `IEEE 802.1s (MSTP)`, `Cisco Rapid-PVST+`
**Concepto base:** [`spanning-tree-and-loop-prevention`](../../concepts/spanning-tree-and-loop-prevention.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# Cisco IOS: Ver quién es el Root Bridge, roles de puertos y bocas bloqueadas por BPDU Guard
show spanning-tree
show spanning-tree summary
show interfaces status err-disabled

# MikroTik RouterOS v7: Ver si este switch es el Root Bridge y roles de cada puerto (root/designated/alternate)
/interface bridge monitor bridge1 once
/interface bridge port monitor [find] once

# Aruba / HP ProCurve: Ver estado RSTP, Root Bridge y contadores de cambios de topología (TCN)
show spanning-tree

# Linux: Ver estado STP y roles de los puertos del bridge
bridge link show
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

Dejar **Spanning Tree** con su configuración de fábrica en una red de switches tiene tres defectos graves:

1. **El jefe de la red (*Root Bridge*) se elige por azar:** Como todos los switches traen prioridad `32768`, gana el que tenga la dirección MAC más vieja.
2. **Las PCs tardan en conectar o fallan al pedir DHCP:** Sin `PortFast / Edge`, el switch demora la boca al encender una PC.
3. **Un empleado puede tirar la oficina si conecta un cable entre dos rosetas de pared:** Sin `BPDU Guard`, `Loop Protect` y `Storm Control`, un bucle abajo inunda de BPDUs o tráfico broadcast a toda la empresa.

En esta guía configuramos **RSTP (`IEEE 802.1w`)** forzando de forma determinista el **Root Bridge Primario (`4096`)** en el Switch Core, el **Root Bridge Secundario (`8192`)** en el Switch de Distribución, y blindando todas las bocas de acceso a usuarios con **`PortFast / Edge` + `BPDU Guard` + `Loop Protect` + `Storm Control`**.

> **🧠 Recordatorio del modelo mental:** Pensá en RSTP como **el sonidista automático que evita el acople ensordecedor entre micrófono y parlante**: vos tenés que decirle explícitamente cuál es la consola principal del escenario (**Root Bridge `4096`**) y ponerle un fusible rápido (**BPDU Guard**) a las tomas del público para que si alguien enchufa un cable en círculo, salte solo esa toma sin apagar el teatro.

---

## 2. 🗺️ Topología de referencia

Implementaremos una topología en triángulo con enlace redundante entre tres switches:

```text
               +-------------------------------------------+
               |           SW-CORE (Root Primario)         |
               |         Prioridad: 4096 (0x1000)          |
               |   Pto 1: DESIGNATED | Pto 2: DESIGNATED   |
               +-------------------------------------------+
                       /                           \
         Enlace 10G   /                             \  Enlace 10G
         (Pto 1)     /                               \ (Pto 1)
                    v                                 v
      Pto 1: ROOT PORT                        Pto 1: ROOT PORT
+---------------------------+           +---------------------------+
| SW-DIST (Root Secundario) |           |  SW-ACCESO (Piso 2)       |
| Prioridad: 8192 (0x2000)  | <=======> |  Prioridad: 32768 (0x8000)|
+---------------------------+  Pto 2    +---------------------------+
 Pto 2: DESIGNATED (FWD)                 Pto 2: ALTERNATE / BLOCKED
                                         -----------------------------------
                                         Ptos 3..24 (Hacia PCs / Cámaras):
                                         - Edge / PortFast = YES
                                         - BPDU Guard      = YES
                                         - Loop Protect    = ON
                                         - Storm Control   = Broadcast 5%
```

| Switch en la Topología | Rol en Spanning Tree | Prioridad decimal | Prioridad en Hex (MikroTik) |
|------------------------|----------------------|:-----------------:|:---------------------------:|
| **`SW-CORE`** | 🏆 **Root Bridge Primario** | **`4096`** | **`0x1000`** |
| **`SW-DIST`** | 🥈 **Root Bridge Secundario (Backup)** | **`8192`** | **`0x2000`** |
| **`SW-ACCESO`** | Switch de Acceso en pisos | **`32768`** (o `28672`) | **`0x8000`** |

---

## 3. 🛠️ Configuración paso a paso por fabricante

### A. Cisco IOS / Catalyst

```cisco
configure terminal

! 1. Activar Rapid-PVST+ (compatible con RSTP 802.1w en el enlace nativo)
spanning-tree mode rapid-pvst
spanning-tree extend system-id

! 2. EN EL SWITCH CORE: Fijar prioridad 4096 en todas las VLANs (Root Primario)
spanning-tree vlan 1-4094 priority 4096
! (En el Switch Secundario SW-DIST usarías: spanning-tree vlan 1-4094 priority 8192)
! (En el Switch de Acceso SW-ACCESO usarías: spanning-tree vlan 1-4094 priority 32768)

! 3. EN LOS PUERTOS TRUNK (Pto 1 y 2): Proteger para que nunca un switch de piso nos robe el trono de Root
interface range GigabitEthernet1/0/1 - 2
 description UPLINKS_ENTRE_SWITCHES
 spanning-tree link-type point-to-point
 ! (Solo en los puertos de SW-CORE que bajan a switches de acceso no confiables: spanning-tree guard root)
exit

! 4. EN LOS PUERTOS DE USUARIOS (Ptos 3 al 24): PortFast + BPDU Guard + Storm Control al 5%
interface range GigabitEthernet1/0/3 - 24
 description PUERTOS_ACCESO_USUARIOS
 spanning-tree portfast
 spanning-tree bpduguard enable
 storm-control broadcast level 5.00
 storm-control multicast level 10.00
 storm-control action trap
exit

! 5. Recuperación automática de puertos err-disabled después de 5 minutos (300 segundos)
errdisable recovery cause bpduguard
errdisable recovery cause storm-control
errdisable recovery interval 300

end
write memory
```

### B. MikroTik RouterOS (v7+)

```text
# 1. Activar RSTP y fijar la prioridad del Switch (0x1000 = 4096 en SW-CORE, 0x2000 = 8192 en SW-DIST, 0x8000 = 32768 en SW-ACCESO)
/interface bridge
set bridge1 protocol-mode=rstp priority=0x1000

# 2. En los puertos TRUNK entre switches (ether1, ether2): edge=no y point-to-point=yes
/interface bridge port
set [find interface=ether1] edge=no point-to-point=yes bpdu-guard=no
set [find interface=ether2] edge=no point-to-point=yes bpdu-guard=no
# (Si en SW-CORE querés impedir que un switch conectado abajo intente proclamarse Root):
# set [find interface=ether2] restricted-role=yes

# 3. En los puertos de ACCESO a PCs/Cámaras (ether3..ether24):
#    - edge=yes (PortFast: levanta instantáneamente sin demorar DHCP)
#    - bpdu-guard=yes (si recibe una BPDU porque enchufaron un switch o bucle, apaga la boca!)
#    - storm-rate=5 (en CRS3xx: frena tormentas de broadcast al 5% de la capacidad del puerto)
/interface bridge port
set [find interface~"ether([3-9]|1[0-9]|2[0-4])"] \
    edge=yes \
    bpdu-guard=yes \
     trusted=no

# 4. Activar además 'loop-protect' en las interfaces físicas de acceso:
#    (¡Vital! Frena bucles incluso dentro de un "switch bobo" doméstico que no envía BPDUs)
/interface ethernet
set [find default-name~"ether([3-9]|1[0-9]|2[0-4])"] \
    loop-protect=on \
    loop-protect-send-interval=5s \
    loop-protect-disable-time=5m
```

### C. Switches Gestionables (Aruba / Ubiquiti / TP-Link)

```text
# En Aruba ProCurve / AOS-S:
configure
# 1. Encender RSTP y fijar prioridad (en Aruba se indica como multiplicador de 4096: 1 = 4096, 2 = 8192, 8 = 32768)
spanning-tree
spanning-tree force-version rstp-operation
spanning-tree priority 1

# 2. Puertos de usuarios (3 al 24): Admin-Edge (PortFast) + BPDU Protection + Loop Protect
spanning-tree 3-24 admin-edge-port
spanning-tree 3-24 bpdu-protection
spanning-tree bpdu-protection-timeout 300
loop-protect 3-24
loop-protect disable-timer 300
interface 3-24 broadcast-limit 5
write memory
```

### D. Linux (`bridge` + `mstpd` / `iproute2`)

```bash
# 1. Activar STP en el bridge y fijar prioridad (4096 para Core, 32768 para Acceso)
sudo ip link set dev br0 type bridge stp_state 1 priority 4096 forward_delay 400

# 2. En un puerto de acceso/VM (eth3), activar BPDU Guard y Root Guard a nivel kernel
sudo bridge link set dev eth3 guard on
sudo bridge link set dev eth3 root_block on
```

---

## 4. 🔑 Salida clave e interpretación de flags

### En MikroTik (`/interface bridge monitor bridge1` y `/interface bridge port monitor`)

```text
[netops@SW-ACCESO] > /interface bridge monitor bridge1 once
                  state: enabled
    current-mac-address: D4:CA:6D:11:22:33
            root-bridge: no
         root-bridge-id: 0x1000.D4:CA:6D:00:00:01
         root-path-cost: 10
              root-port: ether1
             port-count: 24
  designated-port-count: 22

[netops@SW-ACCESO] > /interface bridge port monitor [find interface~"ether[1-3]"] once
Columns: INTERFACE, ROLE, STATE, LEARNING, FORWARDING, EDGE-PORT
#  INTERFACE  ROLE            STATE       LEARNING  FORWARDING  EDGE-PORT
0  ether1     root-port       forwarding  yes       yes         no
1  ether2     alternate-port  discarding  no        no          no
2  ether3     designated-port forwarding  yes       yes         yes
```

### En Cisco IOS (`show spanning-tree vlan 10`)

```text
SW-ACCESO# show spanning-tree vlan 10
VLAN0010
  Spanning tree enabled protocol rstp
  Root ID    Priority    4106
             Address     001a.2b3c.4d01
             Cost        4
             Port        1 (GigabitEthernet1/0/1)
             Hello Time   2 sec  Max Age 20 sec  Forward Delay 15 sec

  Bridge ID  Priority    32778  (priority 32768 sys-id-ext 10)
             Address     001a.2b99.8877

Interface           Role Sts Cost      Prio.Nbr Type
------------------- ---- --- --------- -------- --------------------------------
Gi1/0/1             Root FWD 4         128.1    P2p
Gi1/0/2             Altn BLK 4         128.2    P2p
Gi1/0/3             Desg FWD 4         128.3    P2p Edge
```

### Tabla de interpretación de columnas y flags

| Columna / Estado | Fabricante | Qué significa realmente | Estado sano vs Estado roto |
|------------------|------------|-------------------------|----------------------------|
| **`root-bridge: yes` / `This bridge is the root`** | Todos | Este switch es el **Root Bridge actual** de la red | ✅ Debe decir `yes` **únicamente en `SW-CORE`**. Si dice `yes` en un switch de oficina, la prioridad está mal |
| **`Role: Root` (`root-port`)** | Todos | Es el único puerto de este switch que apunta por el camino más corto hacia el `SW-CORE` | Siempre debe ser tu puerto Trunk principal (ej. `Gi1/0/1` / `ether1`) en estado `FWD` (`forwarding`) |
| **`Role: Altn BLK` (`alternate-port / discarding`)** | Todos | **Puerto redundante en pausa lógica:** RSTP detectó el anillo y bloqueó este puerto para evitar el bucle | ✅ Es normal y sano en el cable de respaldo (`Gi1/0/2` / `ether2`). Pasará a `FWD` en `< 1s` si cae el puerto 1 |
| **`Priority 4106` (`4096 + 10`)** | Cisco (`Rapid-PVST+`) | Cisco suma la prioridad base (`4096`) más el número de VLAN (`10` = `4106`) gracias a `extend system-id` | Es normal; indica prioridad `4096` en la `VLAN 10` |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: Una boca de escritorio se apagó sola y el usuario dice que "no prenden las luces de la placa de red"

1. **Verificación rápida:**
   - En Cisco: `show interfaces status err-disabled` y `show logging | include BPDU`.
   - En MikroTik: `/interface bridge port print where status~"disabled"` o `/interface ethernet monitor ether5 once` (`loop-protect-status: disabled`).
2. **Qué significa:** El usuario conectó un cable en bucle o un switch en esa boca y **`BPDU Guard` / `Loop Protect` apagó el puerto para salvar al resto de la empresa**.
3. **Corrección:** Ir al puesto (o pedir que desconecten el cable/switch extra) y reactivar el puerto:
   - En Cisco: `interface Gi1/0/5` → `shutdown` → `no shutdown`.
   - En MikroTik: `/interface bridge port disable [find interface=ether5]` → `enable [find interface=ether5]`.

### Síntoma 2: Conectás un switch Cisco (que corre `Rapid-PVST+` por VLAN) contra un switch MikroTik o Aruba (que corre `RSTP` único) y una VLAN queda bloqueada

1. **Cómo interoperan:**
   - Cisco `Rapid-PVST+` envía BPDUs estándar `802.1w` sin etiquetar por la **VLAN 1 (o Native VLAN)** y además envía BPDUs propietarias de Cisco (`01:00:0C:CC:CC:CD`) etiquetadas dentro de cada VLAN.
   - El switch MikroTik en modo `rstp` procesa las BPDUs estándar y reenvía (inunda) las BPDUs propietarias de Cisco como si fueran tráfico multicast normal.
2. **Solución limpia para interoperabilidad multi-vendor:**
   - Asegurate de que ambos extremos del Trunk tengan exactamente la misma **Native VLAN** (o usá **`MSTP` — `IEEE 802.1s`** en ambos switches si necesitás múltiples árboles por VLAN entre marcas distintas).

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **¿Qué pasa si cambiás la prioridad del Root Bridge en horario laboral?**
  - Cuando un nuevo switch con prioridad `4096` reclama el trono de Root Bridge, RSTP renegocia los roles de los puertos troncales en `< 1 segundo`. Aun así, hacelo siempre desde el propio `SW-CORE` primero para que el flujo de tráfico se alinee con tu topología física real.

---

## 7. ⚠️ Errores comunes en producción

- **❌ Activar `bpduguard` en un puerto Trunk que va hacia otro switch de infraestructura:** Si ponés `bpdu-guard=yes` en el puerto `ether1` que te conecta al switch vecino, apenas el switch vecino envíe su saludo BPDU normal a los 2 segundos, **tu puerto Trunk se apagará (`err-disabled`) y dejarás aislado a todo el switch**. `BPDU Guard` y `Edge / PortFast` van **únicamente en bocas hacia dispositivos finales (PCs, cámaras, impresoras, servidores sin STP)**.
- **❌ Conectar 2 cables entre dos switches sin haber configurado antes LACP (`Bonding / EtherChannel`) esperando tener el doble de velocidad:** Sin LACP, RSTP bloqueará uno de los dos cables (`Alternate / BLK`). Si querés usar ambos cables a la vez, debés agruparlos primero con LACP (`802.3ad`).

---

## 8. ✅ Buenas prácticas profesionales

- **Nunca dejar un solo switch de la red con la prioridad por defecto sin documentar su rol:** En tu estándar de despliegue, `SW-CORE-1` lleva siempre `4096` (`0x1000`), `SW-CORE-2` lleva `8192` (`0x2000`), los switches de distribución llevan `16384` (`0x4000`) y los switches de acceso llevan `32768` (`0x8000`).
- **Combinar siempre las 3 defensas en puertos de acceso:** **`Edge/PortFast` + `BPDU Guard` + `Loop Protect / Storm Control (5% Broadcast)`**. Así estás cubierto tanto si conectan un switch gestionable que manda BPDUs como si conectan un switch hogareño bobo que no manda BPDUs.

---

## 9. 🔗 Referencias internas

- [`spanning-tree-and-loop-prevention`](../../concepts/spanning-tree-and-loop-prevention.md) — Explicación conceptual profunda de las tormentas de broadcast, elección de Root Bridge y timers
- [`lacp-etherchannel-bonding`](lacp-etherchannel-bonding.md) — Cómo unir 2 o 4 cables entre switches para que RSTP los vea como un solo enlace y no bloquee ninguno
- [`symptom-to-layer-troubleshooting-matrix`](../../reference/symptom-to-layer-troubleshooting-matrix.md) — Qué hacer en los primeros 30 segundos de una tormenta de broadcast
