⬅️ [Volver a Guías](../README.md)

# VLANs (802.1Q), Puertos Access, Trunk, Híbridos y PVID — Guía práctica multi-vendor

**Dominio:** `02-switching-l2`
**Nivel:** 🟡 Intermedio
**Estándares:** `IEEE 802.1Q`
**Concepto base:** [`vlans-tagged-untagged-and-trunks`](../../concepts/vlans-tagged-untagged-and-trunks.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# Cisco IOS: Ver tabla de VLANs, puertos Access y enlaces Trunk con su Native VLAN
show vlan brief
show interfaces trunk
show interfaces Gi1/0/1 switchport

# MikroTik RouterOS v7: Ver tabla Bridge VLAN Filtering, PVID por puerto y Hardware Offload (H)
/interface bridge vlan print
/interface bridge port print
/interface bridge print

# Aruba / HP ProCurve: Ver VLANs y membrecía Tagged/Untagged de un puerto
show vlans
show vlans ports 1-24 detail

# Linux (bridge vlan-aware): Ver PVID y etiquetas por puerto del bridge
bridge vlan show
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

Esta guía traduce el modelo mental de **Ingress (`PVID`) → Core → Egress (`Tagged / Untagged`)** a comandos listos para producción en las cuatro familias de switches y sistemas más utilizados del mercado.

Cubre los **4 escenarios reales que vas a configurar en cualquier empresa**:

1. **Puerto Trunk Puro (`Puerto 1`):** Enlace troncal que sube al Router o une dos switches llevando todas las VLANs etiquetadas (`Tagged 802.1Q`).
2. **Puertos Access de Usuarios y Cámaras (`Puertos 2 y 3`):** Bocas para PCs o cámaras IP que no entienden etiquetas (`Untagged + PVID`).
3. **Puerto Híbrido para Access Point WiFi / Teléfono VoIP (`Puerto 4`):** Boca que entrega la VLAN de Gestión (`VLAN 99`) sin etiqueta (`Untagged / Native VLAN`) para el propio AP y al mismo tiempo transporta etiquetadas (`Tagged`) las VLANs de los SSIDs (`VLAN 10 Staff` y `VLAN 200 Invitados`).
4. **Interfaz IP de Gestión del propio Switch (`VLAN 99`):** Para administrar el switch por SSH en `10.1.99.2/24` sin usar la insegura VLAN 1.

> **🧠 Recordatorio del modelo mental:** Pensá en el **`PVID` (`access vlan` / `native vlan`)** como el sticker de color que el empleado de la ventanilla le pega a toda caja que entra desnuda desde afuera, en **`Tagged` (`trunk`)** como dejarle el sticker puesto cuando sube al camión hacia otro switch, y en **`Untagged` (`access`)** como arrancarle el sticker antes de entregársela en mano a una PC daltónica.

---

## 2. 🗺️ Topología de referencia

Los 4 bloques de configuración siguientes arman **exactamente el mismo switch (`SW-ACCESO`, IP `10.1.99.2/24`)** con las mismas bocas y las mismas VLANs:

```text
                       [RTR-BORDE: Gateway de todas las VLANs]
                                         ||
                                         || Puerto 1: TRUNK PURO (Tagged: 10, 99, 100, 200)
                                         v
             +--------------------------------------------------------+
             |            SW-ACCESO (IP Gestión: 10.1.99.2/24)        |
             |            Gateway de Gestión: 10.1.99.1               |
             +--------------------------------------------------------+
               |                         |                          |
    Puerto 2: ACCESS          Puerto 3: ACCESS           Puerto 4: HÍBRIDO (AP WiFi)
    VLAN 10 (Staff)           VLAN 100 (CCTV)            Untagged (PVID): VLAN 99 (Mgmt AP)
    (PVID=10, Untagged=10)    (PVID=100, Untagged=100)   Tagged: VLAN 10 y VLAN 200 (SSIDs)
               |                         |                          |
               v                         v                          v
        [PC-Contabilidad]         [Cámara IP PoE]             [AP Ubiquiti UniFi]
         (10.1.10.50/24)          (10.1.100.50/24)             (IP AP: 10.1.99.51)
```

| Puerto en la Topología | Nombre en Cisco | Nombre en MikroTik | Nombre en Aruba | Nombre en Linux | Rol y VLANs |
|------------------------|:---------------:|:------------------:|:---------------:|:---------------:|-------------|
| **Puerto 1 (Uplink Router)** | `Gi1/0/1` | `ether1` | `1` | `eth1` | **Trunk Puro:** `10, 99, 100, 200` (`Tagged`) |
| **Puerto 2 (PC Staff)** | `Gi1/0/2` | `ether2` | `2` | `eth2` | **Access VLAN 10:** `PVID=10` (`Untagged`) |
| **Puerto 3 (Cámara CCTV)** | `Gi1/0/3` | `ether3` | `3` | `eth3` | **Access VLAN 100:** `PVID=100` (`Untagged`) |
| **Puerto 4 (AP WiFi)** | `Gi1/0/4` | `ether4` | `4` | `eth4` | **Híbrido:** `PVID=99` (`Untagged 99`) + `Tagged 10, 200` |
| **Puertos 5–24 (Libres)** | `Gi1/0/5-24` | `ether5..24` | `5-24` | — | **Parking VLAN 999** + `shutdown / disabled` |

---

## 3. 🛠️ Configuración paso a paso por fabricante

> ⚠️ **Salvavidas antes de empezar:** Si estás conectado al switch por red, activá **Safe Mode (`Ctrl+X`)** en MikroTik o `reload in 10` en Cisco antes de activar el filtrado de VLANs.

### A. Cisco IOS / Catalyst

```cisco
configure terminal

! 1. Dar de alta las VLANs en la base de datos de Capa 2 del switch (¡obligatorio!)
vlan 10
 name STAFF
vlan 99
 name MANAGEMENT
vlan 100
 name CCTV
vlan 200
 name WIFI_GUEST
vlan 999
 name PARKING_UNUSED
exit

! 2. PUERTO 1: Enlace Trunk hacia el Router (solo permite las VLANs necesarias)
interface GigabitEthernet1/0/1
 description UPLINK_RTR_BORDE
 switchport mode trunk
 switchport trunk native vlan 999
 switchport trunk allowed vlan 10,99,100,200
 switchport nonegotiate
exit

! 3. PUERTO 2: Puerto Access para PC en VLAN 10
interface GigabitEthernet1/0/2
 description PC_CONTABILIDAD
 switchport mode access
 switchport access vlan 10
 switchport nonegotiate
 spanning-tree portfast
 spanning-tree bpduguard enable
exit

! 4. PUERTO 3: Puerto Access para Cámara IP en VLAN 100
interface GigabitEthernet1/0/3
 description CAMARA_ACCESO_PRINCIPAL
 switchport mode access
 switchport access vlan 100
 spanning-tree portfast
 spanning-tree bpduguard enable
exit

! 5. PUERTO 4: Puerto Híbrido para Access Point (Gestión sin etiqueta en 99 + SSIDs etiquetados en 10 y 200)
interface GigabitEthernet1/0/4
 description AP_UNIFI_RECEPCION
 switchport mode trunk
 switchport trunk native vlan 99
 switchport trunk allowed vlan 10,99,200
 spanning-tree portfast trunk
exit

! 6. PUERTOS LIBRES (5 al 24): Mandar a VLAN 999 muerta y apagarlos
interface range GigabitEthernet1/0/5 - 24
 description PUERTO_LIBRE_DESHABILITADO
 switchport mode access
 switchport access vlan 999
 shutdown
exit

! 7. Configurar la IP de Administración del propio Switch en la VLAN 99
interface Vlan1
 no ip address
 shutdown
interface Vlan99
 description SVI_MANAGEMENT
 ip address 10.1.99.2 255.255.255.0
 no shutdown
exit
ip default-gateway 10.1.99.1

end
write memory
```

### B. MikroTik RouterOS v7 (`Bridge VLAN Filtering` moderno con Hardware Offload)

> **🚨 Regla de oro en MikroTik:** Cuando querés que la propia CPU del MikroTik tenga una IP en la `VLAN 99` (para administrarlo en `10.1.99.2`), **SIEMPRE debés incluir al propio `bridge1` dentro de la lista `tagged=bridge1,ether1` de la VLAN 99** en `/interface bridge vlan`. Si te olvidás de poner `bridge1` como `tagged`, apenas actives `vlan-filtering=yes` cortarás la comunicación entre el chip del switch y la CPU del MikroTik y te quedarás afuera.

```text
# 1. Crear el bridge único (sin activar vlan-filtering todavía hasta terminar la tabla!)
/interface bridge
add name=bridge1 vlan-filtering=no protocol-mode=rstp comment="Bridge Principal L2"

# 2. Definir el comportamiento de ENTRADA (Ingress / PVID y frame-types) de cada puerto físico:
/interface bridge port
# Puerto 1 (Trunk puro: solo acepta tramas que ya vengan con etiqueta 802.1Q)
add bridge=bridge1 interface=ether1 frame-types=admit-only-vlan-tagged ingress-filtering=yes comment="UPLINK_RTR_BORDE"
# Puerto 2 (Access VLAN 10: solo acepta tramas desnudas y les clava PVID=10)
add bridge=bridge1 interface=ether2 pvid=10 frame-types=admit-only-untagged-and-priority-tagged ingress-filtering=yes edge=yes comment="PC_CONTABILIDAD"
# Puerto 3 (Access VLAN 100: solo acepta tramas desnudas y les clava PVID=100)
add bridge=bridge1 interface=ether3 pvid=100 frame-types=admit-only-untagged-and-priority-tagged ingress-filtering=yes edge=yes comment="CAMARA_ACCESO"
# Puerto 4 (Híbrido AP: acepta todo; a lo que entra desnudo le clava PVID=99 y respeta lo etiquetado)
add bridge=bridge1 interface=ether4 pvid=99 frame-types=admit-all ingress-filtering=yes edge=yes comment="AP_UNIFI_RECEPCION"

# 3. Definir la tabla de SALIDA (Egress: quién sale Tagged y quién sale Untagged en cada VLAN):
#    *(Nota: RouterOS agrega automáticamente como 'untagged' al puerto cuyo PVID coincida con la VLAN)*
/interface bridge vlan
add bridge=bridge1 vlan-ids=10  tagged=ether1,ether4 untagged=ether2 comment="VLAN 10 Staff"
add bridge=bridge1 vlan-ids=99  tagged=bridge1,ether1 untagged=ether4 comment="VLAN 99 Management (incluye CPU bridge1!)"
add bridge=bridge1 vlan-ids=100 tagged=ether1 untagged=ether3 comment="VLAN 100 CCTV"
add bridge=bridge1 vlan-ids=200 tagged=ether1,ether4 comment="VLAN 200 WiFi Guest"

# 4. Crear la interfaz VLAN 99 de Capa 3 sobre el bridge1 para darle IP de Gestión al Switch
/interface vlan
add interface=bridge1 name=vlan99-mgmt vlan-id=99
/ip address
add address=10.1.99.2/24 interface=vlan99-mgmt comment="IP Gestion Switch"
/ip route
add dst-address=0.0.0.0/0 gateway=10.1.99.1

# 5. AHORA SÍ (con Safe Mode Ctrl+X activo!): Encender el filtrado de VLANs en el chip
/interface bridge set bridge1 vlan-filtering=yes
```

### C. Switches Gestionables (Aruba / Ubiquiti / TP-Link Omada)

```text
# En Aruba ProCurve / AOS-S (Lógica directa: adentro de cada VLAN decís quién es Tagged y quién es Untagged):
configure

vlan 10
   name "STAFF"
   tagged 1,4
   untagged 2
   exit
vlan 99
   name "MANAGEMENT"
   tagged 1
   untagged 4
   ip address 10.1.99.2 255.255.255.0
   exit
vlan 100
   name "CCTV"
   tagged 1
   untagged 3
   exit
vlan 200
   name "WIFI_GUEST"
   tagged 1,4
   exit
vlan 999
   name "PARKING"
   untagged 5-24
   exit

ip default-gateway 10.1.99.1
interface 5-24 disable
write memory
```

> **⚠️ Atención en Switches Web (TP-Link JetStream / D-Link / Netgear):** En las interfaces gráficas web, marcar un puerto como **`Untagged`** en la VLAN 10 **NO cambia automáticamente su `PVID`**. Siempre tenés que hacer **dos pasos** en el menú `802.1Q VLAN`:
>
> 1. En *VLAN Config*: poner el puerto 2 como `Untagged` en la VLAN 10 (y quitarlo de la VLAN 1).
> 2. En la pestaña *Port Config (PVID)*: cambiar el **`PVID` del puerto 2 a `10`**.

### D. Linux (`iproute2` — Bridge `vlan_filtering 1` nativo del Kernel)

```bash
# 1. Crear un bridge único sensible a VLANs (exactamente igual que el chip de un switch físico!)
sudo ip link add name br0 type bridge vlan_filtering 1
sudo ip link set dev br0 up

# 2. Incorporar las interfaces físicas al bridge
for iface in eth1 eth2 eth3 eth4; do
  sudo ip link set dev "$iface" master br0
  sudo ip link set dev "$iface" up
  sudo bridge vlan del dev "$iface" vid 1
done
sudo bridge vlan del dev br0 vid 1 self

# 3. Puerto 1 (eth1): Trunk Puro (VLANs 10, 99, 100, 200 Tagged)
for vid in 10 99 100 200; do
  sudo bridge vlan add dev eth1 vid "$vid"
done

# 4. Puerto 2 (eth2): Access VLAN 10 (PVID + Untagged)
sudo bridge vlan add dev eth2 vid 10 pvid untagged

# 5. Puerto 3 (eth3): Access VLAN 100 (PVID + Untagged)
sudo bridge vlan add dev eth3 vid 100 pvid untagged

# 6. Puerto 4 (eth4): Híbrido AP (Untagged 99 con PVID + Tagged 10 y 200)
sudo bridge vlan add dev eth4 vid 99 pvid untagged
sudo bridge vlan add dev eth4 vid 10
sudo bridge vlan add dev eth4 vid 200

# 7. Darle IP de gestión al propio host Linux en la VLAN 99 (incluyendo 'self' en br0)
sudo bridge vlan add dev br0 vid 99 self
sudo ip link add link br0 name br0.99 type vlan id 99
sudo ip addr add 10.1.99.2/24 dev br0.99
sudo ip link set dev br0.99 up
```

---

## 4. 🔑 Salida clave e interpretación de flags

### En MikroTik (`/interface bridge vlan print` y `/interface bridge port print`)

```text
[netops@SW-ACCESO] > /interface bridge vlan print
Columns: BRIDGE, VLAN-IDS, CURRENT-TAGGED, CURRENT-UNTAGGED
# BRIDGE   VLAN-IDS  CURRENT-TAGGED  CURRENT-UNTAGGED
0 bridge1        10  ether1          ether2
                     ether4
1 bridge1        99  bridge1         ether4
                     ether1
2 bridge1       100  ether1          ether3
3 bridge1       200  ether1
                     ether4

[netops@SW-ACCESO] > /interface bridge port print
Flags: H - HW-OFFLOAD
Columns: INTERFACE, BRIDGE, HW, PVID, FRAME-TYPES
#   INTERFACE  BRIDGE   HW   PVID  FRAME-TYPES
0 H ether1     bridge1  yes     1  admit-only-vlan-tagged
1 H ether2     bridge1  yes    10  admit-only-untagged-and-priority-tagged
2 H ether3     bridge1  yes   100  admit-only-untagged-and-priority-tagged
3 H ether4     bridge1  yes    99  admit-all
```

### En Cisco IOS (`show interfaces trunk`)

```text
SW-ACCESO# show interfaces trunk
Port        Mode             Encapsulation  Status        Native vlan
Gi1/0/1     on               802.1q         trunking      999
Gi1/0/4     on               802.1q         trunking      99

Port        Vlans allowed on trunk
Gi1/0/1     10,99,100,200
Gi1/0/4     10,99,200

Port        Vlans in spanning tree forwarding state and not pruned
Gi1/0/1     10,99,100,200
Gi1/0/4     10,99,200
```

### Tabla de interpretación de columnas y flags

| Columna / Flag | Fabricante | Qué significa realmente | Estado sano vs Estado roto |
|----------------|------------|-------------------------|----------------------------|
| **`H` (`HW-OFFLOAD`)** | MikroTik (`bridge port`) | El filtrado de VLANs se está haciendo **en el chip ASIC de hardware** a velocidad de cable (`0%` uso de CPU) | ✅ Sano: flag `H` presente en todos los puertos físicos. ❌ Roto: falta `H` (creaste más de 1 bridge en el mismo chip) |
| **`CURRENT-TAGGED` vs `TAGGED`** | MikroTik (`bridge vlan`) | `CURRENT-TAGGED` muestra los puertos que **hoy están con Link UP** y transportando activamente esa VLAN | Si un puerto está en `TAGGED` pero no aparece en `CURRENT-TAGGED`, su cable físico está desconectado (`Link Down`) |
| **`Vlans in spanning tree forwarding state`** | Cisco (`show interfaces trunk`) | Son las VLANs que **realmente están pasando tráfico** después de pasar los3 filtros: 1) Permitidas en el trunk, 2) Creadas en `show vlan brief`, y 3) No bloqueadas por STP | ❌ **Trampa común en Cisco:** Una VLAN figura en `Vlans allowed on trunk`, pero **no aparece en esta última lista** porque te olvidaste de crearla con el comando global `vlan <ID>`! |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: En Cisco agregaste `switchport trunk allowed vlan add 50` en el Trunk, pero la VLAN 50 no pasa tráfico

1. **Verificación rápida:** `show interfaces trunk` y `show vlan brief`.
2. **Qué buscar en la salida:** En `show interfaces trunk`, la VLAN `50` aparece en la primera lista (*Vlans allowed*), pero **NO aparece** en la segunda ni tercera lista (*Vlans active / forwarding*).
3. **Corrección:** Entrar a `configure terminal` y escribir `vlan 50` → `name NUEVA_VLAN` → `exit`. Apenas la das de alta en la base de datos L2, pasa a `forwarding` automáticamente.

### Síntoma 2: En Cisco alguien quiso agregar la VLAN 50 a un Trunk en producción y dejó sin red a toda la empresa

1. **Qué pasó (El comando más peligroso de Cisco IOS):**
   - El técnico escribió `switchport trunk allowed vlan 50` **olvidándose la palabra `add`**.
   - En Cisco IOS, escribir `allowed vlan 50` **sin la palabra `add` BORRA todas las VLANs anteriores (`10, 99, 100, 200`)** y deja exclusivamente la VLAN 50 en el cable troncal, cortando instantáneamente toda la empresa.
2. **Regla inquebrantable en Cisco:** Para sumar o quitar una VLAN en un trunk vivo, escribí siempre **`switchport trunk allowed vlan add 50`** o **`switchport trunk allowed vlan remove 50`**.

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **Antes de tocar un Trunk en Cisco:**
  - Copiá la línea actual con `show running-config interface Gi1/0/1` y activá `configure terminal revert timer 5` (o `reload in 5`).
- **Rollback rápido de filtrado VLAN en MikroTik:**
  - Si algo no funciona como esperabas tras encender el filtrado en un bridge y todavía tenés acceso por otro puerto o consola: `/interface bridge set bridge1 vlan-filtering=no` devuelve el switch a modo conmutación plana mientras revisás la tabla `/interface bridge vlan print`.

---

## 7. ⚠️ Errores comunes en producción

- **❌ Crear un bridge distinto por cada VLAN en MikroTik (`bridge-vlan10`, `bridge-vlan20`, `bridge-vlan30`):** Ese era un anticuado truco de software de hace 10 años. En cualquier equipo moderno con RouterOS v7, el chip de hardware **solo puede acelerar (`H`) UN ÚNICO bridge por switch chip**. Si creás 3 bridges, los bridges 2 y 3 pierden el flag `H` y todo su tráfico pasa por la CPU principal, desplomando el rendimiento. **Usá siempre UN SOLO `bridge1` con `vlan-filtering=yes`.**
- **❌ Olvidar `ingress-filtering=yes` y `frame-types=admit-only-untagged-and-priority-tagged` en las bocas de usuarios:** Si dejás una boca de usuario en `admit-all`, un atacante conectado en esa boca puede inyectar tramas ya etiquetadas con la `VLAN 99` o `VLAN 40` (*VLAN Hopping*). Con `admit-only-untagged-and-priority-tagged`, el switch rechaza en la puerta cualquier etiqueta que un usuario intente falsificar.

---

## 8. ✅ Buenas prácticas profesionales

- **Usar siempre el mismo número en VLAN ID, Subred y Subinterfaz:** Si es la VLAN `20`, la subred es `10.1.20.0/24`, la interfaz es `vlan20` y el VRRP es `VRID 20`. Esa simetría elimina el 90% de los errores humanos a las 3 de la mañana.
- **Desactivar DTP (*Dynamic Trunking Protocol*) en todos los puertos de switches Cisco (`switchport nonegotiate`):** Evita que alguien conecte un equipo malicioso a una boca y negocie automáticamente un enlace Trunk con el switch.

---

## 9. 🔗 Referencias internas

- [`vlans-tagged-untagged-and-trunks`](../../concepts/vlans-tagged-untagged-and-trunks.md) — El modelo mental completo de etiquetas 802.1Q, Ingress (PVID) y Egress (Tagged/Untagged)
- [`mikrotik-bridge-vlan-filtering-deep-dive`](../06-mikrotik/mikrotik-bridge-vlan-filtering-deep-dive.md) — Guía avanzada de la arquitectura interna del Switch Chip y CPU en MikroTik
- [`spanning-tree-rstp-bpduguard`](spanning-tree-rstp-bpduguard.md) — El paso siguiente obligatorio en todo switch con VLANs: blindarlo contra bucles con RSTP y BPDU Guard
