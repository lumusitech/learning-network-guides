⬅️ [Volver a Escenarios](../README.md)

# 🧩 Escenario: Falla de conectividad en VLAN o alerta de Native VLAN Mismatch entre switches de distintas marcas

**Dominio:** `l1-l2`
**Nivel:** 🟡 Intermedio
**Capas OSI afectadas:** `Capa 2 (IEEE 802.1Q Trunking)`
**Equipos involucrados:** `Cisco IOS`, `MikroTik RouterOS`, `Aruba / Ubiquiti / TP-Link`

---

## 🎯 Problema

Se instala un nuevo switch **MikroTik CRS326 (`SW-PISO2`)** conectado por el puerto `ether1` al puerto `Gi1/0/24` del switch principal **Cisco Catalyst (`SW-CORE`)**. Las PCs de la `VLAN 10 (Staff)` en el Piso 2 funcionan perfecto, pero **las cámaras de la nueva `VLAN 100 (CCTV)` en el Piso 2 no se ven con el NVR** y en la consola del Cisco aparece cada 60 segundos la alerta: `%CDP-4-NATIVE_VLAN_MISMATCH: Native VLAN mismatch discovered on GigabitEthernet1/0/24 (99), with SW-PISO2 ether1 (1)`.

```text
+-----------------------------------+                +-----------------------------------+
|       SW-CORE (Cisco IOS)         |                |     SW-PISO2 (MikroTik CRS326)    |
|  Puerto Gi1/0/24 (Trunk):         |                |  Puerto ether1 (Trunk):           |
|  - Native VLAN = 99               | <============> |  - PVID = 1 (¡Difiere del 99!)    |
|  - Allowed VLANs = 10, 99         |                |  - Tagged VLANs = 10, 99, 100     |
|  (¡Falta la 100 en el Cisco!)     |                +-----------------------------------+
+-----------------------------------+
```

---

## ⚡ Quick command (NetOps Triage en 30 segundos)

```text
# Cisco IOS: Ver Native VLAN, VLANs permitidas y cuáles están realmente activas en Spanning Tree
show interfaces trunk
show vlan brief

# MikroTik RouterOS v7: Ver tabla de VLANs del bridge (CURRENT-TAGGED) y PVID de cada puerto
/interface bridge vlan print
/interface bridge port print where interface=ether1

# Aruba / HP ProCurve: Ver detalle de VLANs Tagged y Untagged (PVID) en el puerto trunk
show vlans ports 24 detail
```

---

## ✅ Salida esperada vs Salida anómala

### Lo que encontrás durante el incidente (Anómalo)

```text
# En Cisco IOS (show interfaces trunk):
Port        Mode             Encapsulation  Status        Native vlan
Gi1/0/24    on               802.1q         trunking      99

Port        Vlans allowed on trunk
Gi1/0/24    10,99

# En MikroTik SW-PISO2 (/interface bridge port print where interface=ether1):
#   INTERFACE  BRIDGE   HW   PVID  FRAME-TYPES
0 H ether1     bridge1  yes     1  admit-all
```

**Interpretación de la evidencia:**

- **Causa 1 (*Native VLAN Mismatch*):** En `SW-CORE (Cisco)` el puerto `Gi1/0/24` tiene **`Native vlan = 99`** (saca la VLAN 99 desnuda sin etiqueta), pero en `SW-PISO2 (MikroTik)` el puerto `ether1` quedó con **`PVID = 1`** (todo lo que entra desnudo lo mete en la VLAN 1), provocando puenteo cruzado entre la VLAN 99 y la VLAN 1.
- **Causa 2 (VLAN 100 ausente en el Trunk del Core):** En `SW-PISO2` se dio de alta la `VLAN 100`, pero en el puerto `Gi1/0/24` de `SW-CORE` solo figuran permitidas `10,99` (o nunca se creó `vlan 100` en la base L2 del Cisco).

---

## 🧠 Diagnóstico por capas

Por qué ocurre este problema y cómo descartar pistas falsas:

- **Hipótesis descartada (Capa 1):** El enlace físico `Gi1/0/24 ↔ ether1` está en `1Gbps Full` y la `VLAN 10` pasa tráfico sin pérdidas por ese mismo cable.
- **Causa raíz (Capa 2 — Reglas de un enlace Trunk `802.1Q`):** Para que una VLAN cruce un cable Trunk entre dos switches, **debe existir en la base de datos de ambos switches y tener exactamente el mismo tratamiento de etiqueta (`Tagged` con `Tagged`, o el mismo `PVID / Native VLAN` si es `Untagged`)** en las dos puntas del cable.

> **🧠 Modelo mental del incidente:** Pensá en el *Native VLAN Mismatch* como **un camión entre dos sucursales donde la Sucursal A acuerda mandar las cajas de "Gerencia (VLAN 99)" sin ningún sticker, pero el empleado que descarga el camión en la Sucursal B tiene orden de meter toda caja sin sticker en el canasto de "Basura General (VLAN 1)"**.

---

## 🛠️ Procedimiento paso a paso (Runbook de diagnóstico)

### 1. Comparar la configuración de salida (`Egress`) y entrada (`Ingress / PVID`) en ambas puntas del cable Trunk

```text
# En Punta A (Cisco SW-CORE):
show running-config interface Gi1/0/24
show vlan id 100

# En Punta B (MikroTik SW-PISO2):
/interface bridge port print where interface=ether1
/interface bridge vlan print
```

### 2. Verificar si el switch aprendió direcciones MAC en la VLAN 100 desde el puerto Trunk

```text
# Cisco IOS:
show mac address-table vlan 100

# MikroTik RouterOS:
/interface bridge host print where vid=100
```

- Si `SW-PISO2` ve las MACs de las cámaras locales en la `VID 100`, pero `SW-CORE` tiene la tabla MAC de la `VLAN 100` vacía en `Gi1/0/24`, las tramas están muriendo en el puerto Trunk de `SW-CORE`.

---

## 🧯 Mitigación y Rollback

> ⚠️ **Salvavidas obligatorio:** Antes de modificar un puerto Trunk en producción, activá **Safe Mode (`Ctrl+X`)** en MikroTik y `reload in 10` en Cisco. **En Cisco, recordá usar siempre la palabra `add` (`switchport trunk allowed vlan add 100`)!**

### 1. Verificar antes de tocar (Backup rápido)

```text
show running-config interface Gi1/0/24
/export file=pre-fix-trunk
```

### 2. Acción correctiva por fabricante (Unificar el Trunk llevando 10, 99 y 100 todas como `Tagged`)

La forma más limpia y segura de conectar dos switches de distintas marcas es hacer que **todas las VLANs productivas (`10, 99, 100`) viajen etiquetadas (`Tagged`)** en el cable Trunk:

#### En Cisco IOS (`SW-CORE`)

```cisco
configure terminal
! 1. Asegurar que la VLAN 100 exista en la base de datos Capa 2 del switch Core:
vlan 100
 name CCTV
exit

! 2. Agregar la VLAN 100 al Trunk (¡USANDO 'add'!) y alinear la Native VLAN:
interface GigabitEthernet1/0/24
 switchport trunk native vlan 999
 switchport trunk allowed vlan add 100
exit
end
write memory
```

#### En MikroTik RouterOS v7 (`SW-PISO2`)

```text
# Configurar ether1 como Trunk Puro (solo acepta tramas etiquetadas 802.1Q) y sacar 10, 99 y 100 todas como Tagged:
/interface bridge port
set [find interface=ether1] pvid=999 frame-types=admit-only-vlan-tagged ingress-filtering=yes

/interface bridge vlan
set [find vlan-ids=10]  tagged=ether1
set [find vlan-ids=99]  tagged=bridge1,ether1
set [find vlan-ids=100] tagged=ether1
```

#### En Switch Gestionable (Aruba / TP-Link)

```text
configure
vlan 10  tagged 24
vlan 99  tagged 24
vlan 100 tagged 24
vlan 999 untagged 24
write memory
```

### 3. Rollback

```text
# Si el equipo remoto exigía gestión Untagged en la VLAN 99 durante la puesta en marcha:
# Cisco:    interface Gi1/0/24 -> switchport trunk native vlan 99
# MikroTik: /interface bridge port set [find interface=ether1] pvid=99 frame-types=admit-all
```

---

## ✅ Verificación post-incidente y Prevención

- [ ] Desaparece la alerta `%CDP-4-NATIVE_VLAN_MISMATCH` en los logs.
- [ ] `show interfaces trunk` en Cisco muestra `10,99,100` en la tercera tabla (*Vlans in spanning tree forwarding state*).
- [ ] `show mac address-table vlan 100` aprende las MACs de ambos lados del enlace Trunk y el NVR recibe video de las cámaras.
- [ ] **Cómo evitar que vuelva a ocurrir:** Estandarizar todos los enlaces entre switches como **Trunks Puros (`admit-only-vlan-tagged` / `native vlan 999`)** donde absolutamente todas las VLANs reales (incluyendo la `VLAN 99 Management`) viajen etiquetadas (`Tagged`).

---

## 🔗 Referencias

- [`vlans-tagged-untagged-and-trunks`](../../concepts/vlans-tagged-untagged-and-trunks.md) — El modelo mental unificado de `Ingress (PVID)` vs `Egress (Tagged/Untagged)`
- [`vlans-8021q-access-trunk-pvid`](../../guides/02-switching-l2/vlans-8021q-access-trunk-pvid.md) — Guía completa paso a paso de configuración de VLANs multi-vendor
